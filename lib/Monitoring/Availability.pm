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
        "logs"                          => undef,   # logs
        "rpttimeperiod"                 => undef,
        "assumeinitialstates"           => undef,
        "assumestateretention"          => undef,
        "assumestatesduringnotrunning"  => undef,
        "includesoftstates"             => undef,
        "itialassumedhoststate"         => undef,
        "initialassumedservicestate"    => undef,
        "backtrack"                     => 4,
    };

    for my $opt_key (keys %options) {
        if(exists $self->{$opt_key}) {
            $self->{$opt_key} = $options{$opt_key};
        }
        else {
            croak("unknown option: $opt_key");
        }
    }

    bless $self, $class;

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
