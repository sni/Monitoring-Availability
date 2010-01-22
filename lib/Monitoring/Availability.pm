package Monitoring::Availability;

use 5.006;
use strict;
use warnings;
use Data::Dumper;
use Carp;

our $VERSION = '0.05_3';


=head1 NAME

Monitoring::Availability - Calculate Availability Data from
Nagios and Icinga Logfiles.

=head1 SYNOPSIS

    use Monitoring::Availability;
    my $ma = Monitoring::Availability->new();

=head1 DESCRIPTION

This module calculates the availability for hosts/server from given logfiles.
The Logfileformat is Nagios/Icinga only.

=head1 REPOSITORY

    Git: http://github.com/sni/Monitoring-Availability

=head1 CONSTRUCTOR

=head2 new ( [ARGS] )

Creates an C<Monitoring::Availability> object. C<new> takes at least the
logs parameter.  Arguments are in key-value pairs.

=over 4

=item rpttimeperiod

report timeperiod. defines a timeperiod for this report. Will use 24x7 if not
specified.

=item assumeinitialstates

Assume the initial host/service state if none is found, default: yes

=item assumestateretention

Assume state retention, default: yes

=item assumestatesduringnotrunning

Assume state during times when the monitoring process is not running, default: yes

=item includesoftstates

Include soft states in the calculation. Only hard states are used otherwise, default: no

=item initialassumedhoststate

Assumed host state if none is found, default: yes

=item initialassumedservicestate

Assumed service state if none is found, default: yes

=item backtrack

Go back this amount of days to find initial states, default: 4

=item services_inherit_hostdowntimes

Services will inherit downtimes from hosts, default: no

=item verbose

verbose mode

=back

=cut

use constant {
    YES                 => 1,
    NO                  => 0,

    STATE_NOT_RUNNING   => -3,
    STATE_UNSPECIFIED   => -2,
    STATE_CURRENT       => -1,

    STATE_UP            =>  0,
    STATE_DOWN          =>  1,
    STATE_UNREACHABLE   =>  2,

    STATE_OK            =>  0,
    STATE_WARNING       =>  1,
    STATE_CRITICAL      =>  2,
    STATE_UNKNOWN       =>  3,
};

sub new {
    my $class = shift;
    unshift(@_, "peer") if scalar @_ == 1;
    my(%options) = @_;

    my $self = {
        'verbose'                        => 0,       # enable verbose output
        'logger'                         => undef,   # logger object used for verbose output
        'rpttimeperiod'                  => undef,
        'assumeinitialstates'            => undef,
        'assumestateretention'           => undef,
        'assumestatesduringnotrunning'   => undef,
        'includesoftstates'              => undef,
        'initialassumedhoststate'        => undef,
        'initialassumedservicestate'     => undef,
        'backtrack'                      => undef,
        'showscheduleddowntime'          => undef,
        'services_inherit_hostdowntimes' => undef,
    };

    bless $self, $class;

    # verify the options we got so far
    $self = $self->_verify_options($self);

    for my $opt_key (keys %options) {
        if(exists $self->{$opt_key}) {
            $self->{$opt_key} = $options{$opt_key};
        }
        else {
            croak("unknown option: $opt_key");
        }
    }

    # create empty log array
    $self->_reset_log_store();

    $self->_log('initialized '.$class);

    return $self;
}


########################################

=head1 METHODS

=head2 calculate

 calculate()

Calculate the availability

=over 4

=item start

Timestamp of start

=item end

Timestamp of end

=item log_string

String containing the logs

=item log_file

File containing the logs

=item log_dir

Directory containing *.log files

=item log_livestatus

Array with logs from a livestatus query

 a sample query could be:
 selectall_arrayref(GET logs...\nColumns: time type options, {Slice => 1})

=back

=cut

sub calculate {
    my $self      = shift;
    my(%opts)     = @_;
    my $options = {
        'start'                          => undef,
        'end'                            => undef,
        'hosts'                          => [],
        'services'                       => [],
        'log_string'                     => undef,   # logs from string
        'log_livestatus'                 => undef,   # logs from a livestatus query
        'log_file'                       => undef,   # logs from a file
        'log_dir'                        => undef,   # logs from a dir
        'rpttimeperiod'                  => $self->{'rpttimeperiod'},
        'assumeinitialstates'            => $self->{'assumeinitialstates'},
        'assumestateretention'           => $self->{'assumestateretention'},
        'assumestatesduringnotrunning'   => $self->{'assumestatesduringnotrunning'},
        'includesoftstates'              => $self->{'includesoftstates'},
        'initialassumedhoststate'        => $self->{'initialassumedhoststate'},
        'initialassumedservicestate'     => $self->{'initialassumedservicestate'},
        'backtrack'                      => $self->{'backtrack'},
        'showscheduleddowntime'          => $self->{'showscheduleddowntime'},
        'services_inherit_hostdowntimes' => $self->{'services_inherit_hostdowntimes'},
    };
    $self->_log('calculate()');
    my $result;

    for my $opt_key (keys %opts) {
        if(exists $options->{$opt_key}) {
            $options->{$opt_key} = $opts{$opt_key};
        }
        else {
            croak("unknown option: $opt_key");
        }
    }

    $options = $self->_set_default_options($options);
    $options = $self->_verify_options($options);

    # create lookup hash for faster access
    $result->{'hosts'}    = {};
    $result->{'services'} = {};
    for my $host (@{$options->{'hosts'}}) {
        $result->{'hosts'}->{$host} = 1;
    }
    for my $service (@{$options->{'services'}}) {
        if(ref $service ne 'HASH') {
            croak("services have to be an array of hashes, for example: [{host => 'hostname', service => 'description'}, ...]\ngot: ".Dumper($service));
        }
        if(!defined $service->{'host'} or !defined $service->{'service'}) {
            croak("services have to be an array of hashes, for example: [{host => 'hostname', service => 'description'}, ...]\ngot: ".Dumper($service));
        }
        $result->{'services'}->{$service->{'host'}}->{$service->{'service'}} = 1;
    }
    $options->{'calc_all'} = 0;
    if(scalar keys %{$result->{'services'}} == 0 and scalar keys %{$result->{'hosts'}} == 0) {
        $self->_log('will calculate availability for all hosts/services found');
        $options->{'calc_all'} = 1;
    }

    unless($options->{'calc_all'}) {
        $self->_set_empty_hosts($options, $result);
        $self->_set_empty_services($options, $result);
    }

    # which source do we use?
    if(defined $options->{'log_string'}) {
        $self->_store_logs_from_string($options->{'log_string'});
    }
    if(defined $options->{'log_file'}) {
        $self->_store_logs_from_file($options->{'log_file'});
    }
    if(defined $options->{'log_dir'}) {
        $self->_store_logs_from_dir($options->{'log_dir'});
    }
    if(defined $options->{'log_livestatus'}) {
        $self->_store_logs_from_livestatus($options->{'log_livestatus'});
    }

    if(scalar @{$self->{'logs'}} >= 0) {
        $self->_compute_availability_from_log_store($result, $options);
    }

    return($result);
}


########################################

=head2 get_condensed_logs

 get_condensed_logs()

returns an array of hashes with the condensed log used for this report

=cut

sub get_condensed_logs {
    my $self = shift;

    return $self->{'log_output'};
}


########################################

=head2 get_full_logs

 get_full_logs()

returns an array of hashes with the full log used for this report

=cut

sub get_full_logs {
    my $self = shift;

    return $self->{'full_log_output'};
}


########################################
# INTERNAL SUBS
########################################
sub _reset_log_store {
    my $self   = shift;

    $self->_log('_reset_log_store()');

    undef $self->{'logs'};
    $self->{'logs'} = [];

    undef $self->{'log_output'};
    $self->{'log_output'} = [];

    return 1;
}

########################################
sub _store_logs_from_string {
    my $self   = shift;
    my $string = shift;
    $self->_log('_store_logs_from_string()');
    return unless defined $string;
    for my $line (split/\n/mx, $string) {
        my $data = $self->_parse_line($line);
        push @{$self->{'logs'}}, $data if defined $data;
    }
    return 1;
}

########################################
sub _store_logs_from_file {
    my $self   = shift;
    my $file   = shift;
    $self->_log('_store_logs_from_file()');
    return unless defined $file;

    open(my $FH, '<', $file) or croak('cannot read file '.$file.': '.$!);
    while(my $line = <$FH>) {
        chomp($line);
        my $data = $self->_parse_line($line);
        push @{$self->{'logs'}}, $data if defined $data;
    }
    close($FH);
    return 1;
}

########################################
sub _store_logs_from_dir {
    my $self   = shift;
    my $dir   = shift;
    $self->_log('_store_logs_from_dir()');

    return unless defined $dir;

    opendir(my $dh, $dir) or croak('cannot open directory '.$dir.': '.$!);
    while(my $file = readdir($dh)) {
        if($file =~ m/\.log$/mx) {
            $self->_store_logs_from_file($dir.'/'.$file);
        }
    }
    closedir $dh;

    return 1;
}

########################################
sub _store_logs_from_livestatus {
    my $self      = shift;
    my $log_array = shift;
    $self->_log('_store_logs_from_livestatus()');
    return unless defined $log_array;
    for my $entry (@{$log_array}) {
        my $data = $self->_parse_livestatus_entry($entry);
        push @{$self->{'logs'}}, $data if defined $data;
    }
    return 1;
}

########################################
sub _parse_livestatus_entry {
    my $self   = shift;
    my $entry  = shift;

    my $string = $entry->{'options'} || '';
    if($string eq '') {
        # extract starts/stops
        $self->_set_from_type($entry, $string);
        return $entry;
    }

    # extract more information from our options
    $self->_set_from_options($entry, $string);

    return $entry;
}

########################################
sub _parse_line {
    my $self   = shift;
    my $string = shift;
    my $return = {
        'time' => '',
        'type' => '',
    };

    return if substr($string, 0, 1, '') ne '[';
    $return->{'time'} = substr($string, 0, 10, '');
    return if substr($string, 0, 2, '') ne '] ';

    $return->{'type'} = $self->_strtok($string, ': ');
    if(!defined $string) {
        # extract starts/stops
        $self->_set_from_type($return, $string);
        return $return;
    }

    # extract more information from our options
    $self->_set_from_options($return, $string);

    return $return;
}

########################################
# search for a token and return first occurance, trim that part from string
sub _strtok {
    my $index = index($_[1], $_[2]);
    if($index != -1) {
        my $value = substr($_[1], 0, $index, '');
        substr($_[1], 0, length($_[2]), '');
        return($value);
    }

    my $value = $_[1];
    undef $_[1];

    # seperator not found
    return($value);
}

########################################
sub _set_from_options {
    my $self   = shift;
    my $data   = shift;
    my $string = shift;

    # Host States
    if(   $data->{'type'} eq 'HOST ALERT'
       or $data->{'type'} eq 'CURRENT HOST STATE'
       or $data->{'type'} eq 'INITIAL HOST STATE'
    ) {
        $data->{'host_name'}     = $self->_strtok($string, ';');
        $data->{'state'}         = $self->_statestr_to_state($self->_strtok($string, ';'));
        $data->{'hard'}          = $self->_softstr_to_hard($self->_strtok($string, ';'));
                                   $self->_strtok($string, ';');
        $data->{'plugin_output'} = $self->_strtok($string, ';');
    }

    # Service States
    elsif(   $data->{'type'} eq 'SERVICE ALERT'
       or $data->{'type'} eq 'CURRENT SERVICE STATE'
       or $data->{'type'} eq 'INITIAL SERVICE STATE'
    ) {
        $data->{'host_name'}           = $self->_strtok($string, ';');
        $data->{'service_description'} = $self->_strtok($string, ';');
        $data->{'state'}               = $self->_statestr_to_state($self->_strtok($string, ';'));
        $data->{'hard'}                = $self->_softstr_to_hard($self->_strtok($string, ';'));
                                         $self->_strtok($string, ';');
        $data->{'plugin_output'}       = $self->_strtok($string, ';');
    }

    # Host Downtimes
    elsif($data->{'type'} eq 'HOST DOWNTIME ALERT') {
        $data->{'host_name'} = $self->_strtok($string, ';');
        $data->{'start'}     = $self->_startstr_to_start($self->_strtok($string, ';'));
    }

    # Service Downtimes
    elsif($data->{'type'} eq 'SERVICE DOWNTIME ALERT') {
        $data->{'host_name'}           = $self->_strtok($string, ';');
        $data->{'service_description'} = $self->_strtok($string, ';');
        $data->{'start'}               = $self->_startstr_to_start($self->_strtok($string, ';'));
    }

    return 1;
}

########################################
sub _set_from_type {
    my $self   = shift;
    my $data   = shift;
    my $string = shift;

    # program starts
    if($data->{'type'} =~ m/\ starting\.\.\./mx) {
        $data->{'proc_start'} = 1;
    }
    elsif($data->{'type'} =~ m/\ restarting\.\.\./mx) {
        $data->{'proc_start'} = 1;
    }

    # program stops
    elsif($data->{'type'} =~ m/shutting\ down\.\.\./mx) {
        $data->{'proc_start'} = 0;
    }
    elsif($data->{'type'} =~ m/Bailing\ out/mx) {
        $data->{'proc_start'} = 0;
        $data->{'proc_err'}   = 1;
    }

    return 1;
}

########################################
sub _startstr_to_start {
    my $self   = shift;
    my $string = shift;

    return 1 if $string eq 'STARTED';
    return 0;
}

########################################
sub _softstr_to_hard {
    my $self   = shift;
    my $string = shift;

    return 1 if $string eq 'HARD';
    return 0;
}

########################################
sub _statestr_to_state {
    my $self   = shift;
    my $string = shift;

    return 0 if $string eq 'UP';
    return 0 if $string eq 'OK';
    return 1 if $string eq 'WARNING';
    return 1 if $string eq 'DOWN';
    return 2 if $string eq 'CRITICAL';
    return 2 if $string eq 'UNREACHABLE';
    return 3 if $string eq 'UNKNOWN';
    return 0 if $string eq 'RECOVERY';
    confess("unknown state: $string");
}

########################################
sub _set_empty_hosts {
    my $self    = shift;
    my $options = shift;
    my $data    = shift;

    my $initial_assumend_state = STATE_UNSPECIFIED;
    if($options->{'assumeinitialstates'}) {
        $initial_assumend_state = $options->{'initialassumedhoststate'};
    }

    $self->_log('_set_empty_hosts()');
    for my $hostname (keys %{$data->{'hosts'}}) {
        $data->{'hosts'}->{$hostname} = {
            'time_up'           => 0,
            'time_down'         => 0,
            'time_unreachable'  => 0,

            'scheduled_time_up'             => 0,
            'scheduled_time_down'           => 0,
            'scheduled_time_unreachable'    => 0,
            'scheduled_time_indeterminate'  => 0,

            'time_indeterminate_nodata'     => 0,
            'time_indeterminate_notrunning' => 0,
        };
        $self->{'host_data'}->{$hostname} = {
            'in_downtime'      => 0,
            'last_state'       => $initial_assumend_state,
            'last_known_state' => undef,
            'last_state_time'  => 0,
        };
    }
    return 1;
}

########################################
sub _set_empty_services {
    my $self    = shift;
    my $options = shift;
    my $data    = shift;
    $self->_log('_set_empty_services()');

    my $initial_assumend_state      = STATE_UNSPECIFIED;
    my $initial_assumend_host_state = STATE_UNSPECIFIED;
    if($options->{'assumeinitialstates'}) {
        $initial_assumend_state      = $options->{'initialassumedservicestate'};
        $initial_assumend_host_state = $options->{'initialassumedhoststate'};
    }

    for my $hostname (keys %{$data->{'services'}}) {
        for my $service_description (keys %{$data->{'services'}->{$hostname}}) {
            $data->{'services'}->{$hostname}->{$service_description} = {
                'time_ok'           => 0,
                'time_warning'      => 0,
                'time_unknown'      => 0,
                'time_critical'     => 0,

                'scheduled_time_ok'             => 0,
                'scheduled_time_warning'        => 0,
                'scheduled_time_unknown'        => 0,
                'scheduled_time_critical'       => 0,
                'scheduled_time_indeterminate'  => 0,

                'time_indeterminate_nodata'     => 0,
                'time_indeterminate_notrunning' => 0,
            };

            # create last service data
            $self->{'service_data'}->{$hostname}->{$service_description} = {
                'in_downtime'      => 0,
                'last_state'       => $initial_assumend_state,
                'last_known_state' => undef,
                'last_state_time'  => 0,
            };
        }
        $self->{'host_data'}->{$hostname} = {
            'in_downtime'      => 0,
            'last_state'       => $initial_assumend_host_state,
            'last_known_state' => undef,
            'last_state_time'  => 0,
        };
    }
    return 1;
}

########################################
sub _compute_availability_from_log_store {
    my $self    = shift;
    my $result  = shift;
    my $options = shift;
    $self->_log('_compute_availability_from_log_store()');
    $self->_log('_compute_availability_from_log_store() report start: '.(scalar localtime $options->{'start'}));
    $self->_log('_compute_availability_from_log_store() report end:   '.(scalar localtime $options->{'end'}));

    # make sure our logs are sorted by time
    @{$self->{'logs'}} = sort { $a->{'time'} <=> $b->{'time'} } @{$self->{'logs'}};

    $self->_log('_compute_availability_from_log_store() sorted logs');

    # process all log lines we got
    my $last_time = -1;
    for my $data (@{$self->{'logs'}}) {
        # if we reach the start date of our report, insert a fake entry
        if($last_time < $options->{'start'} and $data->{'time'} > $options->{'start'}) {
            $self->_insert_fake_start_event($result, $options);
        }

        # end of report reached, insert fake end event
        if($data->{'time'} > $options->{'end'} and $last_time < $options->{'end'}) {
            $self->_insert_fake_end_event($result, $options);

            # set a log entry
            $self->_add_log_entry(
                            'options'     => $options,
                            'report_end'  => 1,
                            'full_only'   => 1,
                            'log'         => {
                                'start'         => $options->{'end'},
                            },
            );
        }

        # now process the real line
        $self->_process_log_line($result, $options, $data);

        # set timestamp of last log line
        $last_time = $data->{'time'};
    }

    # processing logfiles finished

    # no start event yet, insert a fake entry
    if($last_time < $options->{'start'}) {
        $self->_insert_fake_start_event($result, $options);
    }

    # no end event yet, insert fake end event
    if($last_time < $options->{'end'}) {
        $self->_insert_fake_end_event($result, $options);

        # set a log entry
        $self->_add_log_entry(
                        'report_end' => 1,
                        'options'    => $options,
                        'full_only'  => 1,
                        'log'        => {
                            'start'         => $options->{'end'},
                        },
        );
    }


    return 1;
}

########################################
sub _process_log_line {
    my $self    = shift;
    my $result  = shift;
    my $options = shift;
    my $data    = shift;

    $self->_log('#######################################');
    $self->_log('_process_log_line() at '.(scalar localtime $data->{'time'}));
    $self->_log($data);

    # only hard states?
    if(!$options->{'includesoftstates'} and defined $data->{'hard'} and $data->{'hard'} != 1) {
        $self->_log('  -> skipped soft state');
        return;
    }

    # skip hosts we dont need
    if($options->{'calc_all'} == 0 and defined $data->{'host_name'} and !defined $self->{'host_data'}->{$data->{'host_name'}} and !defined $self->{'service_data'}->{$data->{'host_name'}}) {
        $self->_log('  -> skipped not needed host event');
        return;
    }

    # skip services we dont need
    if($options->{'calc_all'} == 0 and defined $data->{'host_name'} and defined $data->{'service_description'} and !defined $self->{'service_data'}->{$data->{'host_name'}}->{$data->{'service_description'}}) {
        $self->_log('  -> skipped not needed service event');
        return;
    }


    # process starts / stops?
    if(defined $data->{'proc_start'}) {
        unless($options->{'assumestatesduringnotrunning'}) {
            if($data->{'proc_start'}) {
                # set an event for all services and set state to no_data
                $self->_log('_process_log_line() process start, inserting fake event for all services');
                for my $host_name (keys %{$self->{'service_data'}}) {
                    for my $service_description (keys %{$self->{'service_data'}->{$host_name}}) {
                        my $last_known_state = $self->{'service_data'}->{$host_name}->{$service_description}->{'last_known_state'};
                        my $last_state = STATE_UNSPECIFIED;
                        $last_state = $last_known_state if defined $last_known_state and $last_known_state >= 0;
                        $self->_set_service_event($host_name, $service_description, $result, $options, { 'start' => $data->{'start'}, 'end' => $data->{'end'}, 'time' => $data->{'time'}, 'state' => $last_state });
                    }
                }
                for my $host_name (keys %{$self->{'host_data'}}) {
                    my $last_known_state = $self->{'host_data'}->{$host_name}->{'last_known_state'};
                    my $last_state = STATE_UNSPECIFIED;
                    $last_state = $last_known_state if defined $last_known_state and $last_known_state >= 0;
                    $self->_set_host_event($host_name, $result, $options, { 'start' => $data->{'start'}, 'end' => $data->{'end'}, 'time' => $data->{'time'}, 'state' => $last_state });
                }
            } else {
                # set an event for all services and set state to not running
                $self->_log('_process_log_line() process stop, inserting fake event for all services');
                for my $host_name (keys %{$self->{'service_data'}}) {
                    for my $service_description (keys %{$self->{'service_data'}->{$host_name}}) {
                        $self->_set_service_event($host_name, $service_description, $result, $options, { 'start' => $data->{'start'}, 'end' => $data->{'end'}, 'time' => $data->{'time'}, 'state' => STATE_NOT_RUNNING });
                    }
                }
                for my $host_name (keys %{$self->{'host_data'}}) {
                    $self->_set_host_event($host_name, $result, $options, { 'start' => $data->{'start'}, 'end' => $data->{'end'}, 'time' => $data->{'time'}, 'state' => STATE_NOT_RUNNING });
                }
            }
        }
        # set a log entry
        if($data->{'proc_start'}) {
            $self->_add_log_entry(
                            'full_only'  => 1,
                            'options'    => $options,
                            'log'        => {
                                'start'         => $data->{'time'},
                                'type'          => 'PROGRAM (RE)START',
                                'plugin_output' => 'Program start',
                                'class'         => 'INDETERMINATE',
                            },
            );
        } else {
            my $plugin_output = 'Normal program termination';
            $plugin_output    = 'Abnormal program termination' if defined $data->{'proc_err'};
            $self->_add_log_entry(
                            'full_only'  => 1,
                            'options'    => $options,
                            'log'        => {
                                'start'         => $data->{'time'},
                                'type'          => 'PROGRAM END',
                                'plugin_output' => $plugin_output,
                                'class'         => 'INDETERMINATE',
                            },
            );
        }
    }

    # service events
    elsif(defined $data->{'service_description'}) {
        my $service_hist = $self->{'service_data'}->{$data->{'host_name'}}->{$data->{'service_description'}};

        if($data->{'type'} eq 'CURRENT SERVICE STATE' or $data->{'type'} eq 'SERVICE ALERT' or $data->{'type'} eq 'INITIAL SERVICE STATE') {
            $self->_set_service_event($data->{'host_name'}, $data->{'service_description'}, $result, $options, $data);

            # set a log entry
            my $state_text;
            if(   $data->{'state'} == STATE_OK     )  { $state_text = "OK";       }
            elsif($data->{'state'} == STATE_WARNING)  { $state_text = "WARNING";  }
            elsif($data->{'state'} == STATE_UNKNOWN)  { $state_text = "UNKNOWN";  }
            elsif($data->{'state'} == STATE_CRITICAL) { $state_text = "CRITICAL"; }
            if(defined $state_text) {
                my $hard = "";
                $hard = " (HARD)" if $data->{'hard'};
                $self->_add_log_entry(
                            'options'     => $options,
                            'log' => {
                                'start'         => $data->{'time'},
                                'type'          => 'SERVICE '.$state_text.$hard,
                                'plugin_output' => $data->{'plugin_output'},
                                'class'         => $state_text,
                            },
                );
            }
        }
        elsif($data->{'type'} eq 'SERVICE DOWNTIME ALERT') {
            undef $data->{'state'}; # we dont know the current state, so make sure it isnt set
            $self->_set_service_event($data->{'host_name'}, $data->{'service_description'}, $result, $options, $data);

            my $start;
            my $plugin_output;
            if($data->{'start'}) {
                $start = "START";
                $plugin_output = 'Start of scheduled downtime';
                $service_hist->{'in_downtime'} = 1;
            }
            else {
                $start = "STOP";
                $plugin_output = 'End of scheduled downtime';
                $service_hist->{'in_downtime'} = 0;
            }

            # set a log entry
            $self->_add_log_entry(
                            'options'     => $options,
                            'log'         => {
                                'start'         => $data->{'time'},
                                'type'          => 'SERVICE DOWNTIME '.$start,
                                'plugin_output' => $plugin_output,
                                'class'         => 'INDETERMINATE',
                            },
            );
        }
        else {
            $self->_log('  -> unknown log type');
        }
    }

    # host events
    elsif(defined $data->{'host_name'}) {
        my $host_hist = $self->{'host_data'}->{$data->{'host_name'}};

        if($data->{'type'} eq 'CURRENT HOST STATE' or $data->{'type'} eq 'HOST ALERT' or $data->{'type'} eq 'INITIAL HOST STATE') {
            $self->_set_host_event($data->{'host_name'}, $result, $options, $data);

            # set a log entry
            my $state_text;
            if(   $data->{'state'} == STATE_UP)          { $state_text = "UP"; }
            elsif($data->{'state'} == STATE_DOWN)        { $state_text = "DOWN"; }
            elsif($data->{'state'} == STATE_UNREACHABLE) { $state_text = "UNREACHABLE"; }
            if(defined $state_text) {
                my $hard = "";
                $hard = " (HARD)" if $data->{'hard'};
                $self->_add_log_entry(
                            'options'     => $options,
                            'log' => {
                                'start'         => $data->{'time'},
                                'type'          => 'HOST '.$state_text.$hard,
                                'plugin_output' => $data->{'plugin_output'},
                                'class'         => $state_text,
                            },
                );
            }
        }
        elsif($data->{'type'} eq 'HOST DOWNTIME ALERT') {
            my $last_state_time = $host_hist->{'last_state_time'};

            if($options->{'services_inherit_hostdowntimes'}) {
                $self->_log('_process_log_line() hostdowntime, inserting fake event for all services');
                # set an event for all services
                for my $service_description (keys %{$self->{'service_data'}->{$data->{'host_name'}}}) {
                    $last_state_time = $self->{'service_data'}->{$data->{'host_name'}}->{$service_description}->{'last_state_time'};
                    $self->_set_service_event($data->{'host_name'}, $service_description, $result, $options, { 'start' => $data->{'start'}, 'end' => $data->{'end'}, 'time' => $data->{'time'} });
                }
            }

            my $start;
            my $plugin_output;
            if($data->{'start'}) {
                $start = "START";
                $plugin_output = 'Start of scheduled downtime';
                $host_hist->{'in_downtime'} = 1;
            }
            else {
                $start = "STOP";
                $plugin_output = 'End of scheduled downtime';
                $host_hist->{'in_downtime'} = 0;
            }

            # set a log entry
            $self->_add_log_entry(
                            'options'     => $options,
                            'log'         => {
                                'start'         => $data->{'time'},
                                'type'          => 'HOST DOWNTIME '.$start,
                                'plugin_output' => $plugin_output,
                                'class'         => 'INDETERMINATE',
                            },
            );
        }
        else {
            $self->_log('  -> unknown log type');
        }
    }
    else {
        $self->_log('  -> unknown log type');
    }

    return 1;
}


########################################
sub _set_service_event {
    my $self                = shift;
    my $host_name           = shift;
    my $service_description = shift;
    my $result              = shift;
    my $options             = shift;
    my $data                = shift;

    $self->_log('_set_service_event()');

    my $host_hist    = $self->{'host_data'}->{$host_name};
    my $service_hist = $self->{'service_data'}->{$host_name}->{$service_description};
    my $service_data = $result->{'services'}->{$host_name}->{$service_description};

    # check if we are inside the report time
    if($options->{'start'} < $data->{'time'} and $options->{'end'} >= $data->{'time'}) {
        # we got a last state?
        if(defined $service_hist->{'last_state'}) {
            my $diff = $data->{'time'} - $service_hist->{'last_state_time'};

            # ok
            if($service_hist->{'last_state'} == STATE_OK) {
                $self->_log('_set_service_event() ok + '.$diff.' seconds ('.$self->_duration($diff).')');
                $service_data->{'time_ok'} += $diff;
                if($service_hist->{'in_downtime'} or ($options->{'services_inherit_hostdowntimes'} and $host_hist->{'in_downtime'})) {
                    $self->_log('_set_service_event() ok sched + '.$diff.' seconds');
                    $service_data->{'scheduled_time_ok'} += $diff
                }
            }

            # warning
            elsif($service_hist->{'last_state'} == STATE_WARNING) {
                $self->_log('_set_service_event() warning + '.$diff.' seconds');
                $service_data->{'time_warning'} += $diff;
                if($service_hist->{'in_downtime'} or ($options->{'services_inherit_hostdowntimes'} and $host_hist->{'in_downtime'})) {
                    $self->_log('_set_service_event() warning sched + '.$diff.' seconds');
                    $service_data->{'scheduled_time_warning'} += $diff
                }
            }

            # critical
            elsif($service_hist->{'last_state'} == STATE_CRITICAL) {
                $self->_log('_set_service_event() critical + '.$diff.' seconds ('.$self->_duration($diff).')');
                $service_data->{'time_critical'} += $diff;
                if($service_hist->{'in_downtime'} or ($options->{'services_inherit_hostdowntimes'} and $host_hist->{'in_downtime'})) {
                    $self->_log('_set_service_event() critical sched + '.$diff.' seconds');
                    $service_data->{'scheduled_time_critical'} += $diff
                }
            }

            # unknown
            elsif($service_hist->{'last_state'} == STATE_UNKNOWN) {
                $self->_log('_set_service_event() unknown + '.$diff.' seconds ('.$self->_duration($diff).')');
                $service_data->{'time_unknown'} += $diff;
                if($service_hist->{'in_downtime'} or ($options->{'services_inherit_hostdowntimes'} and $host_hist->{'in_downtime'})) {
                    $self->_log('_set_service_event() unknown sched + '.$diff.' seconds');
                    $service_data->{'scheduled_time_unknown'} += $diff
                }
            }

            # no data yet
            elsif($service_hist->{'last_state'} == STATE_UNSPECIFIED) {
                $self->_log('_set_service_event() indeterminate + '.$diff.' seconds ('.$self->_duration($diff).')');
                $service_data->{'time_indeterminate_nodata'} += $diff;
                if($service_hist->{'in_downtime'} or ($options->{'services_inherit_hostdowntimes'} and $host_hist->{'in_downtime'})) {
                    $self->_log('_set_service_event() indeterminate sched + '.$diff.' seconds');
                    $service_data->{'scheduled_time_indeterminate'} += $diff
                }
            }

            # not running
            elsif($service_hist->{'last_state'} == STATE_NOT_RUNNING) {
                $self->_log('_set_service_event() not_running + '.$diff.' seconds ('.$self->_duration($diff).')');
                $service_data->{'time_indeterminate_notrunning'} += $diff;
            }

        }
    }

    # set last state
    if(defined $data->{'state'}) {
        $self->_log('_set_service_event() set last state = '.$data->{'state'});
        $service_hist->{'last_state'}  = $data->{'state'};

        $service_hist->{'last_known_state'} = $data->{'state'} if $data->{'state'} >= 0;
    }

    $service_hist->{'last_state_time'} = $data->{'time'};

    return 1;
}


########################################
sub _set_host_event {
    my $self                = shift;
    my $host_name           = shift;
    my $result              = shift;
    my $options             = shift;
    my $data                = shift;

    $self->_log('_set_host_event()');

    my $host_hist = $self->{'host_data'}->{$host_name};
    my $host_data = $result->{'hosts'}->{$host_name};

    # check if we are inside the report time
    if($options->{'start'} < $data->{'time'} and $options->{'end'} >= $data->{'time'}) {
        # we got a last state?
        if(defined $host_hist->{'last_state'}) {
            my $diff = $data->{'time'} - $host_hist->{'last_state_time'};
            my $state_text;

            # up
            if($host_hist->{'last_state'} == STATE_UP) {
                $state_text = "UP";
                $self->_log('_set_host_event() up + '.$diff.' seconds ('.$self->_duration($diff).')');
                $host_data->{'time_up'} += $diff;
                if($host_hist->{'in_downtime'}) {
                    $self->_log('_set_host_event() up sched + '.$diff.' seconds');
                    $host_data->{'scheduled_time_up'} += $diff
                }
            }

            # down
            elsif($host_hist->{'last_state'} == STATE_DOWN) {
                $state_text = "DOWN";
                $self->_log('_set_host_event() down + '.$diff.' seconds');
                $host_data->{'time_down'} += $diff;
                if($host_hist->{'in_downtime'}) {
                    $self->_log('_set_host_event() down sched + '.$diff.' seconds');
                    $host_data->{'scheduled_time_down'} += $diff
                }
            }

            # unreachable
            elsif($host_hist->{'last_state'} == STATE_UNREACHABLE) {
                $state_text = "UNREACHABLE";
                $self->_log('_set_host_event() unreachable + '.$diff.' seconds ('.$self->_duration($diff).')');
                $host_data->{'time_unreachable'} += $diff;
                if($host_hist->{'in_downtime'}) {
                    $self->_log('_set_host_event() unreachable sched + '.$diff.' seconds');
                    $host_data->{'scheduled_time_unreachable'} += $diff
                }
            }

            # no data yet
            elsif($host_hist->{'last_state'} == STATE_UNSPECIFIED) {
                $self->_log('_set_host_event() indeterminate + '.$diff.' seconds ('.$self->_duration($diff).')');
                $host_data->{'time_indeterminate_nodata'} += $diff;
                if($host_hist->{'in_downtime'}) {
                    $self->_log('_set_host_event() indeterminate sched + '.$diff.' seconds');
                    $host_data->{'scheduled_time_indeterminate'} += $diff
                }
            }

            # not running
            elsif($host_hist->{'last_state'} == STATE_NOT_RUNNING) {
                $self->_log('_set_host_event() not_running + '.$diff.' seconds ('.$self->_duration($diff).')');
                $host_data->{'time_indeterminate_notrunning'} += $diff;
            }

            # set a log entry
            if(defined $state_text) {
                my $hard = "";
                $hard = " (HARD)" if $data->{'hard'};
                $self->_add_log_entry(
                            'options'     => $options,
                            'log'         => {
                                'start'         => $data->{'time'},
                                'type'          => 'HOST '.$state_text.$hard,
                                'plugin_output' => $data->{'plugin_output'},
                                'class'         => $state_text,
                            },
                );
            }
        }
    }

    # set last state
    if(defined $data->{'state'}) {
        $self->_log('_set_host_event() set last state = '.$data->{'state'});
        $host_hist->{'last_state'} = $data->{'state'};

        $host_hist->{'last_known_state'} = $data->{'state'} if $data->{'state'} >= 0;
    }
    $host_hist->{'last_state_time'} = $data->{'time'};

    return 1;
}


########################################
sub _log {
    my $self = shift;
    my $text = shift;

    if($self->{'verbose'} and defined $self->{'logger'}) {
        if(ref $text ne '') {
            $text = Dumper($text);
        }
        $self->{'logger'}->debug($text);
    }

    return 1;
}

##############################################
# calculate a duration in the
# format: 0d 0h 29m 43s
sub _duration {
    my $self     = shift;
    my $duration = shift;

    croak("undef duration in duration(): ".$duration) unless defined $duration;
    $duration = $duration * -1 if $duration < 0;

    if($duration < 0) { $duration = time() + $duration; }

    my $days    = 0;
    my $hours   = 0;
    my $minutes = 0;
    my $seconds = 0;
    if($duration >= 86400) {
        $days     = int($duration/86400);
        $duration = $duration%86400;
    }
    if($duration >= 3600) {
        $hours    = int($duration/3600);
        $duration = $duration%3600;
    }
    if($duration >= 60) {
        $minutes  = int($duration/60);
        $duration = $duration%60;
    }
    $seconds = $duration;

    return($days."d ".$hours."h ".$minutes."m ".$seconds."s");
}

########################################
sub _insert_fake_start_event {
    my $self    = shift;
    my $result  = shift;
    my $options = shift;

    $self->_log('_insert_fake_start_event()');
    for my $host (keys %{$result->{'services'}}) {
        for my $service (keys %{$result->{'services'}->{$host}}) {
            my $last_service_state = STATE_UNSPECIFIED;
            if(defined $self->{'service_data'}->{$host}->{$service}->{'last_state'}) {
                $last_service_state = $self->{'service_data'}->{$host}->{$service}->{'last_state'};
            }
            my $fakedata = {
                'service_description' => $service,
                'time'                => $options->{'start'},
                'host_name'           => $host,
                'type'                => 'INITIAL SERVICE STATE',
                'hard'                => 1,
                'state'               => $last_service_state,
            };
            $self->_process_log_line($result, $options, $fakedata);
        }
    }

    for my $host (keys %{$result->{'hosts'}}) {
        my $last_host_state = STATE_UNSPECIFIED;
        if(defined $self->{'host_data'}->{$host}->{'last_state'}) {
            $last_host_state = $self->{'host_data'}->{$host}->{'last_state'};
        }
        my $fakedata = {
            'time'                => $options->{'start'},
            'host_name'           => $host,
            'type'                => 'INITIAL HOST STATE',
            'hard'                => 1,
            'state'               => $last_host_state,
        };
        $self->_process_log_line($result, $options, $fakedata);
    }

    return 1;
}

########################################
sub _insert_fake_end_event {
    my $self    = shift;
    my $result  = shift;
    my $options = shift;

    # process a fake last entry with our last known state
    $self->_log('_insert_fake_end_event()');
    for my $host (keys %{$result->{'services'}}) {
        for my $service (keys %{$result->{'services'}->{$host}}) {
            my $fakedata = {
                'service_description' => $service,
                'time'                => $options->{'end'},
                'host_name'           => $host,
                'type'                => 'INITIAL SERVICE STATE',
                'hard'                => 1,
                'state'               => $self->{'service_data'}->{$host}->{$service}->{'last_state'},
            };
            $self->_process_log_line($result, $options, $fakedata);
        }
    }

    for my $host (keys %{$result->{'hosts'}}) {
        my $fakedata = {
            'time'                => $options->{'end'},
            'host_name'           => $host,
            'type'                => 'INITIAL HOST STATE',
            'hard'                => 1,
            'state'               => $self->{'host_data'}->{$host}->{'last_state'},
        };
        $self->_process_log_line($result, $options, $fakedata);
    }

    return 1;
}

########################################
sub _set_default_options {
    my $self    = shift;
    my $options = shift;

    $options->{'backtrack'}                      = 4             unless defined $options->{'backtrack'};
    $options->{'assumeinitialstates'}            = 'yes'         unless defined $options->{'assumeinitialstates'};
    $options->{'assumestateretention'}           = 'yes'         unless defined $options->{'assumestateretention'};
    $options->{'assumestatesduringnotrunning'}   = 'yes'         unless defined $options->{'assumestatesduringnotrunning'};
    $options->{'includesoftstates'}              = 'no'          unless defined $options->{'includesoftstates'};
    $options->{'initialassumedhoststate'}        = 'unspecified' unless defined $options->{'initialassumedhoststate'};
    $options->{'initialassumedservicestate'}     = 'unspecified' unless defined $options->{'initialassumedservicestate'};
    $options->{'showscheduleddowntime'}          = 'yes'         unless defined $options->{'showscheduleddowntime'};
    $options->{'services_inherit_hostdowntimes'} = 'no'          unless defined $options->{'services_inherit_hostdowntimes'};

    return $options;
}

########################################
sub _verify_options {
    my $self    = shift;
    my $options = shift;

    # set default backtrack to 4 days
    if(defined $options->{'backtrack'}) {
        if($options->{'backtrack'} < 0) {
            $options->{'backtrack'} = 4;
        }
    }

    # our yes no options
    for my $yes_no (qw/assumeinitialstates
                       assumestateretention
                       assumestatesduringnotrunning
                       includesoftstates
                       showscheduleddowntime
                       services_inherit_hostdowntimes
                      /) {
        if(defined $options->{$yes_no}) {
            if(lc $options->{$yes_no} eq 'yes') {
                $options->{$yes_no} = YES;
            }
            elsif(lc $options->{$yes_no} eq 'no') {
                $options->{$yes_no} = NO;
            } else {
                croak($yes_no.' unknown, please use \'yes\' or \'no\'. Got: '.$options->{$yes_no});
            }
        }
    }

    # set initial assumed host state
    if(defined $options->{'initialassumedhoststate'}) {
        if(lc $options->{'initialassumedhoststate'} eq 'unspecified') {
            $options->{'initialassumedhoststate'} = STATE_UNSPECIFIED;
        }
        elsif(lc $options->{'initialassumedhoststate'} eq 'current') {
            $options->{'initialassumedhoststate'} = STATE_CURRENT;
        }
        elsif(lc $options->{'initialassumedhoststate'} eq 'up') {
            $options->{'initialassumedhoststate'} = STATE_UP;
        }
        elsif(lc $options->{'initialassumedhoststate'} eq 'down') {
            $options->{'initialassumedhoststate'} = STATE_DOWN;
        }
        elsif(lc $options->{'initialassumedhoststate'} eq 'unreachable') {
            $options->{'initialassumedhoststate'} = STATE_UNREACHABLE;
        }
        else {
            croak('initialassumedhoststate unknown, please use one of: unspecified, current, up, down or unreachable. Got: '.$options->{'initialassumedhoststate'});
        }
    }

    # set initial assumed service state
    if(defined $options->{'initialassumedservicestate'}) {
        if(lc $options->{'initialassumedservicestate'} eq 'unspecified') {
            $options->{'initialassumedservicestate'} = STATE_UNSPECIFIED;
        }
        elsif(lc $options->{'initialassumedservicestate'} eq 'current') {
            $options->{'initialassumedservicestate'} = STATE_CURRENT;
        }
        elsif(lc $options->{'initialassumedservicestate'} eq 'ok') {
            $options->{'initialassumedservicestate'} = STATE_OK;
        }
        elsif(lc $options->{'initialassumedservicestate'} eq 'warning') {
            $options->{'initialassumedservicestate'} = STATE_WARNING;
        }
        elsif(lc $options->{'initialassumedservicestate'} eq 'unknown') {
            $options->{'initialassumedservicestate'} = STATE_UNKNOWN;
        }
        elsif(lc $options->{'initialassumedservicestate'} eq 'critical') {
            $options->{'initialassumedservicestate'} = STATE_CRITICAL;
        }
        else {
            croak('initialassumedservicestate unknown, please use one of: unspecified, current, ok, warning, unknown or critical. Got: '.$options->{'initialassumedservicestate'});
        }
    }

    return $options;
}

########################################
sub _add_log_entry {
    my $self    = shift;
    my %opts    = @_;

    $self->_log('_add_log_entry()');

    if(defined $self->{'last_log_entry'}) {
        my $last_options   = $self->{'last_log_entry'};
        my $last_log_entry = $last_options->{'log'};

        # inside of report time?
        if(    $opts{'options'}->{'start'} <  $last_log_entry->{'start'}
           and $opts{'options'}->{'end'}   >= $last_log_entry->{'start'}
          ) {
            $self->_log('  -> added log to stack');
            $last_log_entry->{'end'}      = $opts{'log'}->{'start'};
            $last_log_entry->{'duration'} = $self->_duration($opts{'log'}->{'start'} - $last_log_entry->{'start'});


            if(defined $opts{'report_end'} and $opts{'report_end'} == 1) {
                $last_log_entry->{'duration'} = $last_log_entry->{'duration'}."+";
            }

            $last_log_entry->{'end'}   = scalar localtime $last_log_entry->{'end'};
            $last_log_entry->{'start'} = scalar localtime $last_log_entry->{'start'};


            $self->_log('  -> added from stack: '.Dumper($last_log_entry));
            if(!defined $last_options->{'full_only'} or $last_options->{'full_only'} == 0) {
                push @{$self->{'log_output'}}, $last_log_entry;
            }
            push @{$self->{'full_log_output'}}, $last_log_entry;
        }
        else {
            $self->_log('  -> discard');
        }
        undef $self->{'last_log_entry'};
    }

    $self->{'last_log_entry'} = \%opts;

    return 1;
}

########################################

1;

=head1 BUGS

Please report any bugs or feature requests to L<http://github.com/sni/Monitoring-Availability/issues>.

=head1 SEE ALSO

You can also look for information at:

=over 4

=item * Search CPAN

L<http://search.cpan.org/dist/Monitoring-Availability/>

=item * Github

L<http://github.com/sni/Monitoring-Availability>

=back

=head1 AUTHOR

Sven Nierlein, E<lt>nierlein@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010 by Sven Nierlein

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__END__
