package Monitoring::Availability;

use 5.006;
use strict;
use warnings;
use Data::Dumper;
use Carp;

our $VERSION = '0.01_1';


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

Assume the initial host/service state if none is found.

=item assumestateretention

Assume state retention

=item assumestatesduringnotrunning

Assume state during times when the monitoring process is not running

=item includesoftstates

Include soft states in the calculation. Only hard states are used otherwise.

=item initialassumedhoststate

Assumed host state if none is found

=item initialassumedservicestate

Assumed service state if none is found

=item backtrack

Go back this amount of days to find initial states

=item verbose

verbose mode

=back

=cut

sub new {
    my $class = shift;
    unshift(@_, "peer") if scalar @_ == 1;
    my(%options) = @_;

    my $self = {
        'verbose'                       => 0,       # enable verbose output
        'rpttimeperiod'                 => undef,
        'assumeinitialstates'           => undef,
        'assumestateretention'          => undef,
        'assumestatesduringnotrunning'  => undef,
        'includesoftstates'             => undef,
        'initialassumedhoststate'       => undef,
        'initialassumedservicestate'    => undef,
        'backtrack'                     => 4,
    };
    bless $self, $class;

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

=back

=cut

sub calculate {
    my $self      = shift;
    my(%opts)     = @_;
    my $options = {
        'start'                         => undef,
        'end'                           => undef,
        'hosts'                         => [],
        'services'                      => [],
        'log_string'                    => undef,   # logs from string
        'log_livestatus'                => undef,   # logs from a livestatus query
        'log_file'                      => undef,   # logs from a file
        'log_dir'                       => undef,   # logs from a dir
        'rpttimeperiod'                 => $self->{'rpttimeperiod'},
        'assumeinitialstates'           => $self->{'assumeinitialstates'}          || 1,
        'assumestateretention'          => $self->{'assumestateretention'}         || 1,
        'assumestatesduringnotrunning'  => $self->{'assumestatesduringnotrunning'} || 1,
        'includesoftstates'             => $self->{'includesoftstates'}            || 0,
        'initialassumedhoststate'       => $self->{'initialassumedhoststate'}      || 0,
        'initialassumedservicestate'    => $self->{'initialassumedservicestate'}   || 0,
        'backtrack'                     => $self->{'backtrack'}                    || 4,
    };
    my $result;

    for my $opt_key (keys %opts) {
        if(exists $options->{$opt_key}) {
            $options->{$opt_key} = $opts{$opt_key};
        }
        else {
            croak("unknown option: $opt_key");
        }
    }

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
        $result->{'services'}->{$service->{'host'}}->{$service->{'service'}} = 1;
    }
    $options->{'calc_all'} = 0;
    if(scalar keys %{$result->{'services'}} == 0 and scalar keys %{$result->{'services'}} == 0) {
        $options->{'calc_all'} = 1;
    }

    #print "calculation availabity with:";
    #print Dumper($options);
    unless($options->{'calc_all'}) {
        $self->_set_empty_hosts($result);
        $self->_set_empty_services($result);
    }
    #print Dumper($result);

    return($result);
}

########################################
# INTERNAL SUBS
########################################
sub _reset_log_store {
    my $self   = shift;
    undef $self->{'logs'};
    $self->{'logs'} = [];
    return 1;
}

########################################
sub _read_logs_from_string {
    my $self   = shift;
    my $string = shift;
    return unless defined $string;
    for my $line (split/\n/mx, $string) {
        my $data = $self->_parse_line($line);
        push @{$self->{'logs'}}, $data if defined $data;
    }
    return 1;
}

########################################
sub _read_logs_from_file {
    my $self   = shift;
    my $file   = shift;
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
sub _read_logs_from_dir {
    my $self   = shift;
    my $dir   = shift;

    return unless defined $dir;

    opendir(my $dh, $dir) or croak('cannot open directory '.$dir.': '.$!);
    while(my $file = readdir($dh)) {
        if($file =~ m/\.log$/mx) {
            $self->_read_logs_from_file($dir.'/'.$file);
        }
    }
    closedir $dh;

    return 1;
}

########################################
sub _parse_line {
    my $self   = shift;
    my $string = shift;
    my $return = {
        'time'                => '',
        'type'                => '',
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
        $data->{'host_name'} = $self->_strtok($string, ';');
        $data->{'state'}     = $self->_statestr_to_state($self->_strtok($string, ';'));
        $data->{'hard'}      = $self->_softstr_to_hard($self->_strtok($string, ';'));
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
    return 0 if $string eq 'RECOVERY';
    return 1 if $string eq 'WARNING';
    return 1 if $string eq 'DOWN';
    return 2 if $string eq 'CRITICAL';
    return 2 if $string eq 'UNREACHABLE';
    return 3 if $string eq 'UNKNOWN';
    confess("unknown state: $string");
}

########################################
sub _set_empty_hosts {
    my $self = shift;
    my $data = shift;
    for my $host (values %{$data->{'hosts'}}) {
        $host = {
            'last_known_state'  => 0,
            'earliest_time'     => 0,
            'latest_time'       => 0,
            'earliest_state'    => 0,
            'latest_state'      => 0,

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
    }
}

########################################
sub _set_empty_services {
    my $self = shift;
    my $data = shift;

    for my $hostname (keys %{$data->{'services'}}) {
        for my $service (values %{$data->{'services'}->{$hostname}}) {
            $service = {
                'last_known_state'  => 0,
                'earliest_time'     => 0,
                'latest_time'       => 0,
                'earliest_state'    => 0,
                'latest_state'      => 0,

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
        }
    }
}

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
