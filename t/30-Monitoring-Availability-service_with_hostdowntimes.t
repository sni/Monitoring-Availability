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
                'time_ok'           => 507245,
                'time_warning'      => 0,
                'time_unknown'      => 0,
                'time_critical'     => 0,

                'scheduled_time_ok'             => 680,
                'scheduled_time_warning'        => 0,
                'scheduled_time_unknown'        => 0,
                'scheduled_time_critical'       => 0,
                'scheduled_time_indeterminate'  => 0,

                'time_indeterminate_nodata'     => 97550,
                'time_indeterminate_notrunning' => 5,
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
    'assumestatesduringnotrunning'  => 'no',
    'initialassumedhoststate'       => 'unspecified',
    'initialassumedservicestate'    => 'unspecified',
);
isa_ok($ma, 'Monitoring::Availability', 'create new Monitoring::Availability object');
my $result = $ma->calculate(
    'log_string'                    => $logs,
    'services'                      => [{'host' => 'n0_test_host_000', 'service' => 'n0_test_random_04'}],
    'start'                         => 1262894050,
    'end'                           => 1263498850,
);
TODO: {
    local $TODO = "not yet implemented";
    is_deeply($result, $expected, 'sample 1 result') or diag("got:\n".Dumper($result)."\nbut expected:\n".Dumper($expected));
}

__DATA__
[1262962252] Nagios 3.2.0 starting... (PID=7873)
[1262991600] CURRENT SERVICE STATE: n0_test_host_000;n0_test_random_04;OK;HARD;1;n0_test_host_000 (checked by mo) REVOVERED: random n0_test_random_04 recovered
[1263042693] HOST DOWNTIME ALERT: n0_test_host_000;STARTED; Host has entered a period of scheduled downtime
[1263043373] HOST DOWNTIME ALERT: n0_test_host_000;STOPPED; Host has exited from a period of scheduled downtime
[1263043555] Caught SIGSEGV, shutting down...
[1263043560] Nagios 3.2.0 starting... (PID=22865)