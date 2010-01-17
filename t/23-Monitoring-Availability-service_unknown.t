#!/usr/bin/env perl

#########################

use strict;
use Test::More tests => 3;
use Data::Dumper;

use_ok('Monitoring::Availability');

#########################
# read logs from data
my $logs;
while(my $line = <DATA>) {
    $logs .= $line;
}

my $expected = {
    'hosts' => {},
    'services' => {
        'n0_test_host_000' => {
            'n0_test_random_04' => {
                'time_ok'           => 0,
                'time_warning'      => 0,
                'time_unknown'      => 507250,
                'time_critical'     => 0,

                'scheduled_time_ok'             => 0,
                'scheduled_time_warning'        => 0,
                'scheduled_time_unknown'        => 0,
                'scheduled_time_critical'       => 0,
                'scheduled_time_indeterminate'  => 0,

                'time_indeterminate_nodata'     => 97550,
                'time_indeterminate_notrunning' => 0,
            }
        }
    }
};

#########################
# create a logger object if we have log4perl installed
my $logger;
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
my $ma = Monitoring::Availability->new(
    'verbose'                       => 1,
    'logger'                        => $logger,
    'backtrack'                     => 4,
    'assumestateretention'          => 'yes',
    'assumeinitialstates'           => 'yes',
    'assumestatesduringnotrunning'  => 0,
    'initialassumedhoststate'       => 0,
    'initialassumedservicestate'    => 0,
);
isa_ok($ma, 'Monitoring::Availability', 'create new Monitoring::Availability object');
my $result = $ma->calculate(
    'log_string'                    => $logs,
    'services'                      => [{'host' => 'n0_test_host_000', 'service' => 'n0_test_random_04'}],
    'start'                         => 1262894050,
    'end'                           => 1263498850,
);
is_deeply($result, $expected, 'unknown service') or diag("got:\n".Dumper($result)."\nbut expected:\n".Dumper($expected));

__DATA__
[1262962252] Nagios 3.2.0 starting... (PID=7873)
[1262991600] CURRENT SERVICE STATE: n0_test_host_000;n0_test_random_04;UNKNOWN;HARD;1;n0_test_host_000 ...
