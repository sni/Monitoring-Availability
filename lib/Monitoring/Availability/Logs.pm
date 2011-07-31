package Monitoring::Availability::Logs;

use 5.008;
use strict;
use warnings;
use Data::Dumper;
use Carp;
use POSIX qw(strftime);

use constant {
    STATE_UP            =>  0,
    STATE_DOWN          =>  1,
    STATE_UNREACHABLE   =>  2,

    STATE_OK            =>  0,
    STATE_WARNING       =>  1,
    STATE_CRITICAL      =>  2,
    STATE_UNKNOWN       =>  3,

    START_NORMAL        =>  1,
    START_RESTART       =>  2,
    STOP_NORMAL         =>  0,
    STOP_ERROR          => -1,
};

=head1 NAME

Monitoring::Availability::Logs - Load/Store/Access Logfiles

=head1 DESCRIPTION

Store for logfiles

=head2 new ( [ARGS] )

Creates an C<Monitoring::Availability::Log> object.

=cut

sub new {
    my $class = shift;
    my(%options) = @_;

    my $self = {
        'verbose'                        => 0,       # enable verbose output
        'logger'                         => undef,   # logger object used for verbose output
        'log_string'                     => undef,   # logs from string
        'log_livestatus'                 => undef,   # logs from a livestatus query
        'log_file'                       => undef,   # logs from a file
        'log_dir'                        => undef,   # logs from a dir
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

    # create an empty log store
    $self->{'logs'} = [];

    # which source do we use?
    if(defined $self->{'log_string'}) {
        $self->_store_logs_from_string($self->{'log_string'});
    }
    if(defined $self->{'log_file'}) {
        $self->_store_logs_from_file($self->{'log_file'});
    }
    if(defined $self->{'log_dir'}) {
        $self->_store_logs_from_dir($self->{'log_dir'});
    }
    if(defined $self->{'log_livestatus'}) {
        $self->_store_logs_from_livestatus($self->{'log_livestatus'});
    }

    return $self;
}

########################################

=head1 METHODS

=head2 get_logs

 get_logs()

returns all read logs as array of hashrefs

=cut

sub get_logs {
    my $self = shift;
    return($self->{'logs'});
}


########################################
# INTERNAL SUBS
########################################
sub _store_logs_from_string {
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
sub _store_logs_from_file {
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
sub _store_logs_from_dir {
    my $self   = shift;
    my $dir   = shift;

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
        $data->{'proc_start'} = START_NORMAL;
    }
    elsif($data->{'type'} =~ m/\ restarting\.\.\./mx) {
        $data->{'proc_start'} = START_RESTART;
    }

    # program stops
    elsif($data->{'type'} =~ m/shutting\ down\.\.\./mx) {
        $data->{'proc_start'} = STOP_NORMAL;
    }
    elsif($data->{'type'} =~ m/Bailing\ out/mx) {
        $data->{'proc_start'} = STOP_ERROR;
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
    return 0 if $string eq 'PENDING';
    confess("unknown state: $string");
}


########################################

1;

=head1 AUTHOR

Sven Nierlein, E<lt>nierlein@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010 by Sven Nierlein

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__END__
