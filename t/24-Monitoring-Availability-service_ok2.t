#!/usr/bin/env perl

#########################

use strict;
use Test::More tests => 4;
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
                'time_ok'           => 604800,
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
            }
        }
    }
};

my $expected_log = [
    { 'start' => '2010-01-09 00:00:00', end => '2010-01-17 14:58:55', 'duration' => '8d 14h 58m 55s',  'type' => 'SERVICE OK (HARD)', plugin_output => 'n0_test_host_000 (checked by mo) REVOVERED: random n0_test_random_04 recovered', 'class' => 'OK' },
    { 'start' => '2010-01-18 00:00:00', end => '2010-01-19 00:00:00', 'duration' => '1d 0h 0m 0s',     'type' => 'SERVICE OK (HARD)', plugin_output => 'n0_test_host_000 (checked by mo) REVOVERED: random n0_test_random_04 recovered', 'class' => 'OK' },
    { 'start' => '2010-01-19 00:00:00', end => '2010-01-20 00:00:00', 'duration' => '1d 0h 0m 0s',     'type' => 'SERVICE OK (HARD)', plugin_output => 'n0_test_host_000 (checked by mo) REVOVERED: random n0_test_random_04 recovered', 'class' => 'OK' },
    { 'start' => '2010-01-20 00:00:00', end => '2010-01-20 22:16:24', 'duration' => '0d 22h 16m 24s+', 'type' => 'SERVICE OK (HARD)', plugin_output => 'n0_test_host_000 (checked by mo) REVOVERED: random n0_test_random_04 recovered', 'class' => 'OK' },
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
    'assumestatesduringnotrunning'  => 'yes',
    'initialassumedhoststate'       => 'unspecified',
    'initialassumedservicestate'    => 'unspecified',
);
isa_ok($ma, 'Monitoring::Availability', 'create new Monitoring::Availability object');
my $result = $ma->calculate(
    'log_string'                    => $logs,
    'services'                      => [{'host' => 'n0_test_host_000', 'service' => 'n0_test_random_04'}],
    'start'                         => 1263417384,
    'end'                           => 1264022184,
);
is_deeply($result, $expected, 'ok service') or diag("got:\n".Dumper($result)."\nbut expected:\n".Dumper($expected));

TODO: {
    local $TODO = "not implemented yet";
    my $condensed_logs = $ma->get_condensed_logs();
    is_deeply($condensed_logs, $expected_log, 'ok service condensed logs') or diag("got:\n".Dumper($condensed_logs)."\nbut expected:\n".Dumper($expected_log));
};

__DATA__
[1262962252] Nagios 3.2.0 starting... (PID=7873)
[1262991600] CURRENT SERVICE STATE: n0_test_host_000;n0_test_random_04;OK;HARD;1;n0_test_host_000 (checked by mo) REVOVERED: random n0_test_random_04 recovered
[1263736735] Nagios 3.2.0 starting... (PID=528)
[1263744146] Caught SIGTERM, shutting down...
[1263744148] Nagios 3.2.0 starting... (PID=21311)
[1263744235] Caught SIGTERM, shutting down...
[1263744238] Nagios 3.2.0 starting... (PID=21471)
[1263744297] Caught SIGTERM, shutting down...
[1263744300] Nagios 3.2.0 starting... (PID=21647)
[1263769200] CURRENT SERVICE STATE: n0_test_host_000;n0_test_random_04;OK;HARD;1;n0_test_host_000 (checked by mo) REVOVERED: random n0_test_random_04 recovered
[1263855600] CURRENT SERVICE STATE: n0_test_host_000;n0_test_random_04;OK;HARD;1;n0_test_host_000 (checked by mo) REVOVERED: random n0_test_random_04 recovered
[1263942000] CURRENT SERVICE STATE: n0_test_host_000;n0_test_random_04;OK;HARD;1;n0_test_host_000 (checked by mo) REVOVERED: random n0_test_random_04 recovered