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
                'last_known_state'  => 0,
                'earliest_time'     => 0,
                'latest_time'       => 0,
                'earliest_state'    => 0,
                'latest_state'      => 0,

                'time_ok'           => 0,
                'time_warning'      => 0,
                'time_unknown'      => 0,
                'time_critical'     => 0,

                'scheduled_time_ok'             => 141343,
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

my $ma = Monitoring::Availability->new(
    'backtrack'                     => 4,
    'assumestateretention'          => 'yes',
    'assumeinitialstates'           => 'yes',
    'assumestatesduringnotrunning'  => 'yes',
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
TODO: {
    local $TODO = "not yet implemented";
    is_deeply($result, $expected, 'sample 1 result');
}

__DATA__
[1262954794] Nagios 3.2.0 starting... (PID=10586)
[1262958290] Caught SIGSEGV, shutting down...
[1262958295] Nagios 3.2.0 starting... (PID=23002)
[1262962252] Nagios 3.2.0 starting... (PID=7873)
[1262991600] CURRENT SERVICE STATE: n0_test_host_000;n0_test_random_04;OK;HARD;1;n0_test_host_000 (checked by mo) REVOVERED: random n0_test_random_04 recovered
[1263042693] HOST DOWNTIME ALERT: n0_test_host_000;STARTED; Host has entered a period of scheduled downtime
[1263042811] Caught SIGTERM, shutting down...
[1263042826] Nagios 3.2.0 starting... (PID=18961)
[1263042829] HOST DOWNTIME ALERT: n0_test_host_000;STARTED; Host has entered a period of scheduled downtime
[1263042836] Nagios 3.2.0 starting... (PID=18979)
[1263042837] HOST DOWNTIME ALERT: n0_test_host_000;STARTED; Host has entered a period of scheduled downtime
[1263043162] Nagios 3.2.0 starting... (PID=20140)
[1263043168] HOST DOWNTIME ALERT: n0_test_host_000;STARTED; Host has entered a period of scheduled downtime
[1263043194] Caught SIGSEGV, shutting down...
[1263043199] Nagios 3.2.0 starting... (PID=21673)
[1263043202] HOST DOWNTIME ALERT: n0_test_host_000;STARTED; Host has entered a period of scheduled downtime
[1263043373] HOST DOWNTIME ALERT: n0_test_host_000;STOPPED; Host has exited from a period of scheduled downtime
[1263043555] Caught SIGSEGV, shutting down...
[1263043560] Nagios 3.2.0 starting... (PID=22865)
[1263043572] Caught SIGSEGV, shutting down...
[1263043577] Nagios 3.2.0 starting... (PID=22889)
[1263043581] Caught SIGSEGV, shutting down...
[1263043587] Nagios 3.2.0 starting... (PID=22911)
[1263043594] Caught SIGSEGV, shutting down...
[1263043599] Nagios 3.2.0 starting... (PID=22932)
[1263046200] HOST DOWNTIME ALERT: n0_test_host_000;STARTED; Host has entered a period of scheduled downtime
[1263046385] HOST DOWNTIME ALERT: n0_test_host_000;STOPPED; Host has exited from a period of scheduled downtime
[1263048706] HOST DOWNTIME ALERT: n0_test_host_000;STARTED; Host has entered a period of scheduled downtime
[1263048890] HOST DOWNTIME ALERT: n0_test_host_000;STOPPED; Host has exited from a period of scheduled downtime
[1263049296] HOST DOWNTIME ALERT: n0_test_host_000;STARTED; Host has entered a period of scheduled downtime
[1263049549] HOST DOWNTIME ALERT: n0_test_host_000;STOPPED; Host has exited from a period of scheduled downtime
[1263050436] Nagios 3.2.0 starting... (PID=14593)
[1263069719] Nagios 3.2.0 starting... (PID=4378)
[1263069728] HOST DOWNTIME ALERT: n0_test_host_000;STARTED; Host has entered a period of scheduled downtime
[1263070072] HOST DOWNTIME ALERT: n0_test_host_000;STOPPED; Host has exited from a period of scheduled downtime
[1263070163] HOST DOWNTIME ALERT: n0_test_host_000;STARTED; Host has entered a period of scheduled downtime
[1263070346] HOST DOWNTIME ALERT: n0_test_host_000;STOPPED; Host has exited from a period of scheduled downtime
[1263078000] CURRENT SERVICE STATE: n0_test_host_000;n0_test_random_04;OK;HARD;1;n0_test_host_000 (checked by mo) REVOVERED: random n0_test_random_04 recovered
[1263121043] Nagios 3.2.0 starting... (PID=21310)
[1263121671] Nagios 3.2.0 starting... (PID=23052)
[1263127678] HOST DOWNTIME ALERT: n0_test_host_000;STARTED; Host has entered a period of scheduled downtime
[1263127967] HOST DOWNTIME ALERT: n0_test_host_000;STOPPED; Host has exited from a period of scheduled downtime
[1263128081] HOST DOWNTIME ALERT: n0_test_host_000;STARTED; Host has entered a period of scheduled downtime
[1263128263] HOST DOWNTIME ALERT: n0_test_host_000;STOPPED; Host has exited from a period of scheduled downtime
[1263234657] Nagios 3.2.0 starting... (PID=22248)
[1263250800] CURRENT SERVICE STATE: n0_test_host_000;n0_test_random_04;OK;HARD;1;n0_test_host_000 (checked by mo) REVOVERED: random n0_test_random_04 recovered
[1263337200] CURRENT SERVICE STATE: n0_test_host_000;n0_test_random_04;OK;HARD;1;n0_test_host_000 (checked by mo) REVOVERED: random n0_test_random_04 recovered
[1263419826] Caught SIGTERM, shutting down...
[1263419828] Nagios 3.2.0 starting... (PID=10277)
[1263423600] CURRENT SERVICE STATE: n0_test_host_000;n0_test_random_04;OK;HARD;1;n0_test_host_000 (checked by mo) REVOVERED: random n0_test_random_04 recovered
[1263458022] Caught SIGTERM, shutting down...
[1263458059] Nagios 3.2.0 starting... (PID=3382)
[1263498357] Caught SIGTERM, shutting down...
[1263498359] Nagios 3.2.0 starting... (PID=20338)
