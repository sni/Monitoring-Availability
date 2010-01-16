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

=item logs

Array of logs

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
        "verbose"                       => 0,       # enable verbose output
        "hosts"                         => [],
        "services"                      => [],
        "log_string"                    => undef,   # logs from string
        "log_array"                     => undef,   # logs from an array
        "log_file"                      => undef,   # logs from a file
        "log_dir"                       => undef,   # logs from a dir
        "start"                         => undef,
        "end"                           => undef,
        "rpttimeperiod"                 => undef,
        "assumeinitialstates"           => undef,
        "assumestateretention"          => undef,
        "assumestatesduringnotrunning"  => undef,
        "includesoftstates"             => undef,
        "initialassumedhoststate"       => undef,
        "initialassumedservicestate"    => undef,
        "backtrack"                     => 4,
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

=cut

sub calculate {
    my $self      = shift;
    return(1);
}

########################################
# INTERNAL SUBS
########################################
sub _reset_log_store {
    my $self   = shift;
    undef $self->{'logs'};
    $self->{'logs'} = [];
}

########################################
sub _parse_log_string {
    my $self   = shift;
    my $string = shift;
    $self->_reset_log_store;
    return unless defined $string;
    for my $line (split/\n/, $string) {
        my $data = $self->_parse_line($line);
        push @{$self->{'logs'}}, $data if defined $data;
    }
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
}

########################################
sub _set_from_type {
    my $self   = shift;
    my $data   = shift;
    my $string = shift;

    # program starts
    if($data->{'type'} =~ m/ starting\.\.\./) {
        $data->{'start'} = 1;
    }
    elsif($data->{'type'} =~ m/ restarting\.\.\./) {
        $data->{'start'} = 1;
    }

    # program stops
    elsif($data->{'type'} =~ m/shutting down\.\.\./) {
        $data->{'start'} = 0;
    }
    elsif($data->{'type'} =~ m/Bailing out/) {
        $data->{'start'} = 0;
    }
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
