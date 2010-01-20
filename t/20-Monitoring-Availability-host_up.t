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
    'services' => {},
    'hosts' => {
        'n0_test_host_000' => {
            'time_up'          => 507250,
            'time_down'        => 0,
            'time_unreachable' => 0,

            'scheduled_time_up'             => 0,
            'scheduled_time_down'           => 0,
            'scheduled_time_unreachable'    => 0,
            'scheduled_time_indeterminate'  => 0,

            'time_indeterminate_nodata'     => 97550,
            'time_indeterminate_notrunning' => 0,
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
    'assumestatesduringnotrunning'  => 'yes',
    'initialassumedhoststate'       => 'unspecified',
    'initialassumedservicestate'    => 'unspecified',
);
isa_ok($ma, 'Monitoring::Availability', 'create new Monitoring::Availability object');
my $result = $ma->calculate(
    'log_string'                    => $logs,
    'hosts'                         => ['n0_test_host_000'],
    'start'                         => 1262894050,
    'end'                           => 1263498850,
);
is_deeply($result, $expected, 'up host') or diag("got:\n".Dumper($result)."\nbut expected:\n".Dumper($expected));

__DATA__
[1262962252] Nagios 3.2.0 starting... (PID=7873)
[1262991600] CURRENT HOST STATE: n0_test_host_000;UP;HARD;1;n0_test_host_000 ...
