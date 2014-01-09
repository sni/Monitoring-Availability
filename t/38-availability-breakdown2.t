#!/usr/bin/env perl

#########################

use strict;
use Test::More;
use Data::Dumper;

# checks against localtime will fail otherwise
use POSIX qw(tzset);
$ENV{'TZ'} = "CET";
POSIX::tzset();

BEGIN {
    if( $^O eq 'MSWin32' ) {
        plan skip_all => 'windows is not supported';
    }
    else {
        plan tests => 7;
    }

    require 't/00_test_utils.pm';
    import TestUtils;
}

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
            'n0_test_pending_01' => {
                'time_ok'           => 114500,
                'time_warning'      => 500,
                'time_unknown'      => 20,
                'time_critical'     => 4796,

                'scheduled_time_ok'             => 114500,
                'scheduled_time_warning'        => 500,
                'scheduled_time_unknown'        => 0,
                'scheduled_time_critical'       => 4782,
                'scheduled_time_indeterminate'  => 55,

                'time_indeterminate_nodata'     => 85733,
                'time_indeterminate_notrunning' => 0,
                'time_indeterminate_outside_timeperiod' => 0,
            }
        }
    }
};

#########################
# avail.cgi?host=n0_test_host_000&service=n0_test_pending_01&t1=1264026307&t2=1264112707&backtrack=4&assumestateretention=yes&assumeinitialstates=yes&assumestatesduringnotrunning=yes&initialassumedhoststate=0&initialassumedservicestate=0&show_log_entries&showscheduleddowntime=yes
sub get_ma {
    my $ma = Monitoring::Availability->new(
        'verbose'                       => 0,
        'backtrack'                     => 4,
        'assumestateretention'          => 'yes',
        'assumeinitialstates'           => 'yes',
        'assumestatesduringnotrunning'  => 'yes',
        'initialassumedhoststate'       => 'unspecified',
        'initialassumedservicestate'    => 'unspecified',
        'showscheduleddowntime'         => 'yes',
        'timeformat'                    => '%Y-%m-%d %H:%M:%S',
    );
    return $ma;
}
sub calculate {
    my($ma, $breakdown) = @_;
    my $result = $ma->calculate(
        'log_string'                    => $logs,
        'services'                      => [{'host' => 'n0_test_host_000', 'service' => 'n0_test_pending_01'}],
        'start'                         => 1264026307,
        'end'                           => 1264231856,
        'breakdown'                     => $breakdown,
    );
    return $result;
}

my $ma = get_ma();
isa_ok($ma, 'Monitoring::Availability', 'create new Monitoring::Availability object');
my $result = calculate($ma, undef);
is_deeply($result, $expected, 'service availability') or diag("got:\n".Dumper($result)."\nbut expected:\n".Dumper($expected));

for my $breakdown (qw/none days weeks months/) {
    $ma = get_ma();
    my $result = calculate($ma, $breakdown);
    delete $result->{services}->{n0_test_host_000}->{n0_test_pending_01}->{breakdown};
    is_deeply($result, $expected, $breakdown.' service availability') or diag("got:\n".Dumper($result)."\nbut expected:\n".Dumper($expected));
}

__DATA__
[1264111515] Nagios 3.2.0 starting... (PID=31189)
[1264111516] Finished daemonizing... (New PID=31195)
[1264111930] SERVICE DOWNTIME ALERT: n0_test_host_000;n0_test_pending_01;STARTED; Service has entered a period of scheduled downtime
[1264111946] SERVICE ALERT: n0_test_host_000;n0_test_pending_01;WARNING;SOFT;1;warn
[1264111985] SERVICE DOWNTIME ALERT: n0_test_host_000;n0_test_pending_01;CANCELLED; Scheduled downtime for service has been cancelled.
[1264112006] SERVICE ALERT: n0_test_host_000;n0_test_pending_01;UNKNOWN;SOFT;2;unknown
[1264112017] PROGRAM_RESTART event encountered, restarting...
[1264112018] Nagios 3.2.0 starting... (PID=31195)
[1264112040] SERVICE ALERT: n0_test_host_000;n0_test_pending_01;UNKNOWN;HARD;3;unknown
[1264112040] SERVICE NOTIFICATION: test_contact;n0_test_host_000;n0_test_pending_01;UNKNOWN;notify-service;unknown
[1264112060] SERVICE ALERT: n0_test_host_000;n0_test_pending_01;CRITICAL;HARD;3;critical
[1264112060] SERVICE NOTIFICATION: test_contact;n0_test_host_000;n0_test_pending_01;CRITICAL;notify-service;critical
[1264116856] SERVICE ALERT: n0_test_host_000;n0_test_pending_01;OK;HARD;0;ok
[1264112074] HOST DOWNTIME ALERT: n0_test_host_000;STARTED; Host has entered a period of scheduled downtime
[1264201356] SERVICE ALERT: n0_test_host_000;n0_test_pending_01;WARNING;HARD;1;warning
[1264201856] SERVICE ALERT: n0_test_host_000;n0_test_pending_01;OK;HARD;0;ok