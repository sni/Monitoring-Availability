#!/usr/bin/env perl

package TestUtils;

#########################
# Test Utils
#########################

use strict;
use Exporter;
use Data::Dumper;
use Test::More;

use vars qw(@ISA @EXPORT); 
@ISA = qw(Exporter);
@EXPORT = qw ($logger);

#########################
# create a logger object if we have log4perl installed
our $logger;
eval {
    if(defined $ENV{'TEST_LOG'}) {
        use Log::Log4perl qw(:easy);
        Log::Log4perl->easy_init($DEBUG);
        Log::Log4perl->init(\ q{
            log4perl.logger                    = DEBUG, Screen
            log4perl.appender.Screen           = Log::Log4perl::Appender::ScreenColoredLevels
            log4perl.appender.Screen.stderr    = 1
            log4perl.appender.Screen.Threshold = DEBUG
            log4perl.appender.Screen.layout    = Log::Log4perl::Layout::PatternLayout
            log4perl.appender.Screen.layout.ConversionPattern = [%d] %m%n
        });
        $logger = get_logger();
    }
};



#########################
sub check_array_one_by_one {
    my $exp  = shift;
    my $got  = shift;
    my $name = shift;

    for(my $x = 0; $x <= scalar @{$exp}; $x++) {
        Test::More::is_deeply($got->[$x], $exp->[$x], $name.' '.$x) or Test::More::diag("got:\n".Dumper($got->[0])."\nbut expected:\n".Dumper($exp->[0]));
    }
    return 1;
}
#########################

1;

__END__

