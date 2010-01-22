#!/usr/bin/env perl

#########################

use strict;
use Test::More tests => 18;
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
            'time_up'           => 507245,
            'time_down'         => 0,
            'time_unreachable'  => 0,

            'scheduled_time_up'             => 680,
            'scheduled_time_down'           => 0,
            'scheduled_time_unreachable'    => 0,
            'scheduled_time_indeterminate'  => 0,

            'time_indeterminate_nodata'     => 97550,
            'time_indeterminate_notrunning' => 5,
        }
    }
};

my $expected_condensed_log = [
    { 'start' => '2010-01-21 23:12:10', end => '2010-01-21 23:13:05', 'duration' => '0d 0h 0m 55s',  'type' => 'SERVICE DOWNTIME START', plugin_output => 'Start of scheduled downtime', 'class' => 'INDETERMINATE' },
    { 'start' => '2010-01-21 23:13:05', end => '2010-01-21 23:13:37', 'duration' => '0d 0h 0m 32s',  'type' => 'SERVICE DOWNTIME END', plugin_output => 'End of scheduled downtime', 'class' => 'INDETERMINATE' },
    { 'start' => '2010-01-21 23:14:00', end => '2010-01-21 23:14:20', 'duration' => '0d 0h 0m 20s',  'type' => 'SERVICE UNKNOWN (HARD)', plugin_output => 'unknown', 'class' => 'UNKNOWN' },
    { 'start' => '2010-01-21 23:14:20', end => '2010-01-21 23:14:34', 'duration' => '0d 0h 0m 14s',  'type' => 'SERVICE CRITICAL (HARD)', plugin_output => 'critical', 'class' => 'CRITICAL' },
    { 'start' => '2010-01-21 23:14:34', end => '2010-01-21 23:25:07', 'duration' => '0d 0h 10m 33s+','type' => 'HOST DOWNTIME START', plugin_output => 'Start of scheduled downtime', 'class' => 'INDETERMINATE' },
];

my $expected_full_log = [
    { 'start' => '2010-01-21 23:05:15', end => '2010-01-21 23:12:10', 'duration' => '0d 0h 6m 55s',  'type' => 'PROGRAM (RE)START', plugin_output => 'Program start', 'class' => 'INDETERMINATE' },
    { 'start' => '2010-01-21 23:12:10', end => '2010-01-21 23:13:05', 'duration' => '0d 0h 0m 55s',  'type' => 'SERVICE DOWNTIME START', plugin_output => 'Start of scheduled downtime', 'class' => 'INDETERMINATE' },
    { 'start' => '2010-01-21 23:13:05', end => '2010-01-21 23:13:37', 'duration' => '0d 0h 0m 32s',  'type' => 'SERVICE DOWNTIME END', plugin_output => 'End of scheduled downtime', 'class' => 'INDETERMINATE' },
    { 'start' => '2010-01-21 23:13:37', end => '2010-01-21 23:13:38', 'duration' => '0d 0h 0m 1s',   'type' => 'PROGRAM (RE)START', plugin_output => 'Program restart', 'class' => 'INDETERMINATE' },
    { 'start' => '2010-01-21 23:13:38', end => '2010-01-21 23:14:00', 'duration' => '0d 0h 0m 22s',  'type' => 'PROGRAM (RE)START', plugin_output => 'Program start', 'class' => 'INDETERMINATE' },
    { 'start' => '2010-01-21 23:14:00', end => '2010-01-21 23:14:20', 'duration' => '0d 0h 0m 20s',  'type' => 'SERVICE UNKNOWN (HARD)', plugin_output => 'unknown', 'class' => 'UNKNOWN' },
    { 'start' => '2010-01-21 23:14:20', end => '2010-01-21 23:14:34', 'duration' => '0d 0h 0m 14s',  'type' => 'SERVICE CRITICAL (HARD)', plugin_output => 'critical', 'class' => 'CRITICAL' },
    { 'start' => '2010-01-21 23:14:34', end => '2010-01-21 23:25:07', 'duration' => '0d 0h 10m 33s+','type' => 'HOST DOWNTIME START', plugin_output => 'Start of scheduled downtime', 'class' => 'INDETERMINATE' },
];

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
    'hosts'                         => ['n0_test_host_000'],
    'start'                         => 1262894050,
    'end'                           => 1263498850,
);
TODO: {
    local $TODO = 'not yet implemented';
    is_deeply($result, $expected, 'host with downtime') or diag("got:\n".Dumper($result)."\nbut expected:\n".Dumper($expected));


    my $condensed_logs = $ma->get_condensed_logs();
    check_one_by_one($expected_condensed_log, $condensed_logs, 'condensed logs');

    my $full_logs = $ma->get_full_logs();
    check_one_by_one($expected_full_log, $full_logs, 'full logs');
};

#########################
sub check_one_by_one {
    my $exp  = shift;
    my $got  = shift;
    my $name = shift;

    for(my $x = 0; $x <= scalar @{$exp}; $x++) {
        is_deeply($got->[$x], $exp->[$x], $name.' '.$x) or diag("got:\n".Dumper($got->[0])."\nbut expected:\n".Dumper($exp->[0]));
    }
    return 1;
}
#########################

__DATA__
[1262962252] Nagios 3.2.0 starting... (PID=7873)
[1262991600] CURRENT HOST STATE: n0_test_host_000;OK;HARD;1;n0_test_host_000 ...
[1263042693] HOST DOWNTIME ALERT: n0_test_host_000;STARTED; Host has entered a period of scheduled downtime
[1263043373] HOST DOWNTIME ALERT: n0_test_host_000;STOPPED; Host has exited from a period of scheduled downtime
[1263043555] Caught SIGSEGV, shutting down...
[1263043560] Nagios 3.2.0 starting... (PID=22865)
