#!/usr/bin/env perl

#########################

use strict;
use Test::More tests => 3;
use Data::Dumper;

use_ok('Monitoring::Availability');

#########################

my $logs = [
    {'options' => '','time' => 1262954794,'type' => 'Nagios 3.2.0 starting... (PID=10586)','class' => '2','state' => '0'},
    {'options' => '','time' => 1262958290,'type' => 'Caught SIGSEGV, shutting down...','class' => '2','state' => '0'},
    {'options' => '','time' => 1262958295,'type' => 'Nagios 3.2.0 starting... (PID=23002)','class' => '2','state' => '0'},
    {'options' => '','time' => 1262962252,'type' => 'Nagios 3.2.0 starting... (PID=7873)','class' => '2','state' => '0'},
    {'plugin_output' => 'n0_test_host_000 (checked by mo) REVOVERED: random n0_test_random_04 recovered','service_description' => 'n0_test_random_04','options' => 'n0_test_host_000;n0_test_random_04;OK;HARD;1;n0_test_host_000 (checked by mo) REVOVERED: random n0_test_random_04 recovered','time' => 1262991600,'state' => '0','host_name' => 'n0_test_host_000','class' => '6','type' => 'CURRENT SERVICE STATE'},
    {'options' => 'n0_test_host_000;STARTED; Host has entered a period of scheduled downtime','time' => 1263042693,'host_name' => 'n0_test_host_000','type' => 'HOST DOWNTIME ALERT','class' => '1','state' => '0'},
    {'options' => '','time' => 1263042811,'type' => 'Caught SIGTERM, shutting down...','class' => '2','state' => '0'},
    {'options' => '','time' => 1263042826,'type' => 'Nagios 3.2.0 starting... (PID=18961)','class' => '2','state' => '0'},
    {'options' => 'n0_test_host_000;STARTED; Host has entered a period of scheduled downtime','time' => 1263042829,'host_name' => 'n0_test_host_000','type' => 'HOST DOWNTIME ALERT','class' => '1','state' => '0'},
    {'options' => '','time' => 1263042836,'type' => 'Nagios 3.2.0 starting... (PID=18979)','class' => '2','state' => '0'},
    {'options' => 'n0_test_host_000;STARTED; Host has entered a period of scheduled downtime','time' => 1263042837,'host_name' => 'n0_test_host_000','type' => 'HOST DOWNTIME ALERT','class' => '1','state' => '0'},
    {'options' => '','time' => 1263043162,'type' => 'Nagios 3.2.0 starting... (PID=20140)','class' => '2','state' => '0'},
    {'options' => 'n0_test_host_000;STARTED; Host has entered a period of scheduled downtime','time' => 1263043168,'host_name' => 'n0_test_host_000','type' => 'HOST DOWNTIME ALERT','class' => '1','state' => '0'},
    {'options' => '','time' => 1263043194,'type' => 'Caught SIGSEGV, shutting down...','class' => '2','state' => '0'},
    {'options' => '','time' => 1263043199,'type' => 'Nagios 3.2.0 starting... (PID=21673)','class' => '2','state' => '0'},
    {'options' => 'n0_test_host_000;STARTED; Host has entered a period of scheduled downtime','time' => 1263043202,'host_name' => 'n0_test_host_000','type' => 'HOST DOWNTIME ALERT','class' => '1','state' => '0'},
    {'options' => 'n0_test_host_000;STOPPED; Host has exited from a period of scheduled downtime','time' => 1263043373,'host_name' => 'n0_test_host_000','type' => 'HOST DOWNTIME ALERT','class' => '1','state' => '0'},
    {'options' => '','time' => 1263043555,'type' => 'Caught SIGSEGV, shutting down...','class' => '2','state' => '0'},
    {'options' => '','time' => 1263043560,'type' => 'Nagios 3.2.0 starting... (PID=22865)','class' => '2','state' => '0'},
    {'options' => '','time' => 1263043572,'type' => 'Caught SIGSEGV, shutting down...','class' => '2','state' => '0'},
    {'options' => '','time' => 1263043577,'type' => 'Nagios 3.2.0 starting... (PID=22889)','class' => '2','state' => '0'},
    {'options' => '','time' => 1263043581,'type' => 'Caught SIGSEGV, shutting down...','class' => '2','state' => '0'},
    {'options' => '','time' => 1263043587,'type' => 'Nagios 3.2.0 starting... (PID=22911)','class' => '2','state' => '0'},
    {'options' => '','time' => 1263043594,'type' => 'Caught SIGSEGV, shutting down...','class' => '2','state' => '0'},
    {'options' => '','time' => 1263043599,'type' => 'Nagios 3.2.0 starting... (PID=22932)','class' => '2','state' => '0'},
    {'options' => 'n0_test_host_000;STARTED; Host has entered a period of scheduled downtime','time' => 1263046200,'host_name' => 'n0_test_host_000','type' => 'HOST DOWNTIME ALERT','class' => '1','state' => '0'},
    {'options' => 'n0_test_host_000;STOPPED; Host has exited from a period of scheduled downtime','time' => 1263046385,'host_name' => 'n0_test_host_000','type' => 'HOST DOWNTIME ALERT','class' => '1','state' => '0'},
    {'options' => 'n0_test_host_000;STARTED; Host has entered a period of scheduled downtime','time' => 1263048706,'host_name' => 'n0_test_host_000','type' => 'HOST DOWNTIME ALERT','class' => '1','state' => '0'},
    {'options' => 'n0_test_host_000;STOPPED; Host has exited from a period of scheduled downtime','time' => 1263048890,'host_name' => 'n0_test_host_000','type' => 'HOST DOWNTIME ALERT','class' => '1','state' => '0'},
    {'options' => 'n0_test_host_000;STARTED; Host has entered a period of scheduled downtime','time' => 1263049296,'host_name' => 'n0_test_host_000','type' => 'HOST DOWNTIME ALERT','class' => '1','state' => '0'},
    {'options' => 'n0_test_host_000;STOPPED; Host has exited from a period of scheduled downtime','time' => 1263049549,'host_name' => 'n0_test_host_000','type' => 'HOST DOWNTIME ALERT','class' => '1','state' => '0'},
    {'options' => '','time' => 1263050436,'type' => 'Nagios 3.2.0 starting... (PID=14593)','class' => '2','state' => '0'},
    {'options' => '','time' => 1263069719,'type' => 'Nagios 3.2.0 starting... (PID=4378)','class' => '2','state' => '0'},
    {'options' => 'n0_test_host_000;STARTED; Host has entered a period of scheduled downtime','time' => 1263069728,'host_name' => 'n0_test_host_000','type' => 'HOST DOWNTIME ALERT','class' => '1','state' => '0'},
    {'options' => 'n0_test_host_000;STOPPED; Host has exited from a period of scheduled downtime','time' => 1263070072,'host_name' => 'n0_test_host_000','type' => 'HOST DOWNTIME ALERT','class' => '1','state' => '0'},
    {'options' => 'n0_test_host_000;STARTED; Host has entered a period of scheduled downtime','time' => 1263070163,'host_name' => 'n0_test_host_000','type' => 'HOST DOWNTIME ALERT','class' => '1','state' => '0'},
    {'options' => 'n0_test_host_000;STOPPED; Host has exited from a period of scheduled downtime','time' => 1263070346,'host_name' => 'n0_test_host_000','type' => 'HOST DOWNTIME ALERT','class' => '1','state' => '0'},
    {'plugin_output' => 'n0_test_host_000 (checked by mo) REVOVERED: random n0_test_random_04 recovered','service_description' => 'n0_test_random_04','options' => 'n0_test_host_000;n0_test_random_04;OK;HARD;1;n0_test_host_000 (checked by mo) REVOVERED: random n0_test_random_04 recovered','time' => 1263078000,'state' => '0','host_name' => 'n0_test_host_000','class' => '6','type' => 'CURRENT SERVICE STATE'},
    {'options' => '','time' => 1263121043,'type' => 'Nagios 3.2.0 starting... (PID=21310)','class' => '2','state' => '0'},{'options' => '','time' => 1263121671,'type' => 'Nagios 3.2.0 starting... (PID=23052)','class' => '2','state' => '0'},
    {'options' => 'n0_test_host_000;STARTED; Host has entered a period of scheduled downtime','time' => 1263127678,'host_name' => 'n0_test_host_000','type' => 'HOST DOWNTIME ALERT','class' => '1','state' => '0'},
    {'options' => 'n0_test_host_000;STOPPED; Host has exited from a period of scheduled downtime','time' => 1263127967,'host_name' => 'n0_test_host_000','type' => 'HOST DOWNTIME ALERT','class' => '1','state' => '0'},
    {'options' => 'n0_test_host_000;STARTED; Host has entered a period of scheduled downtime','time' => 1263128081,'host_name' => 'n0_test_host_000','type' => 'HOST DOWNTIME ALERT','class' => '1','state' => '0'},
    {'options' => 'n0_test_host_000;STOPPED; Host has exited from a period of scheduled downtime','time' => 1263128263,'host_name' => 'n0_test_host_000','type' => 'HOST DOWNTIME ALERT','class' => '1','state' => '0'},
    {'options' => '','time' => 1263234657,'type' => 'Nagios 3.2.0 starting... (PID=22248)','class' => '2','state' => '0'},{'plugin_output' => 'n0_test_host_000 (checked by mo) REVOVERED: random n0_test_random_04 recovered','service_description' => 'n0_test_random_04','options' => 'n0_test_host_000;n0_test_random_04;OK;HARD;1;n0_test_host_000 (checked by mo) REVOVERED: random n0_test_random_04 recovered','time' => 1263250800,'state' => '0','host_name' => 'n0_test_host_000','class' => '6','type' => 'CURRENT SERVICE STATE'},{'plugin_output' => 'n0_test_host_000 (checked by mo) REVOVERED: random n0_test_random_04 recovered','service_description' => 'n0_test_random_04','options' => 'n0_test_host_000;n0_test_random_04;OK;HARD;1;n0_test_host_000 (checked by mo) REVOVERED: random n0_test_random_04 recovered','time' => 1263337200,'state' => '0','host_name' => 'n0_test_host_000','class' => '6','type' => 'CURRENT SERVICE STATE'},
    {'options' => '','time' => 1263419826,'type' => 'Caught SIGTERM, shutting down...','class' => '2','state' => '0'},
    {'options' => '','time' => 1263419828,'type' => 'Nagios 3.2.0 starting... (PID=10277)','class' => '2','state' => '0'},
    {'plugin_output' => 'n0_test_host_000 (checked by mo) REVOVERED: random n0_test_random_04 recovered','service_description' => 'n0_test_random_04','options' => 'n0_test_host_000;n0_test_random_04;OK;HARD;1;n0_test_host_000 (checked by mo) REVOVERED: random n0_test_random_04 recovered','time' => 1263423600,'state' => '0','host_name' => 'n0_test_host_000','class' => '6','type' => 'CURRENT SERVICE STATE'},
    {'options' => '','time' => 1263458022,'type' => 'Caught SIGTERM, shutting down...','class' => '2','state' => '0'},
    {'options' => '','time' => 1263458059,'type' => 'Nagios 3.2.0 starting... (PID=3382)','class' => '2','state' => '0'},
    {'options' => '','time' => 1263498357,'type' => 'Caught SIGTERM, shutting down...','class' => '2','state' => '0'},
    {'options' => '','time' => 1263498359,'type' => 'Nagios 3.2.0 starting... (PID=20338)','class' => '2','state' => '0'},
];

my $expected = {
    'hosts' => {
        'n0_test_host_000' => {
            'n0_test_random_00' => {
                'ok_scheduled'             => { 'total' => 141343, 'percent' => 23.331, 'percent_of_known' => 27.687 },
                'ok_unscheduled'           => { 'total' => 366807, 'percent' => 60.649, 'percent_of_known' => 72.313 },
                'ok_total'                 => { 'total' => 507250, 'percent' => 83.871, 'percent_of_known' => 100.00 },

                'warning_scheduled'        => { 'total' => 0, 'percent' => 0, 'percent_of_known' => 0 },
                'warning_unscheduled'      => { 'total' => 0, 'percent' => 0, 'percent_of_known' => 0 },
                'warning_total'            => { 'total' => 0, 'percent' => 0, 'percent_of_known' => 0 },

                'unknown_scheduled'        => { 'total' => 0, 'percent' => 0, 'percent_of_known' => 0 },
                'unknown_unscheduled'      => { 'total' => 0, 'percent' => 0, 'percent_of_known' => 0 },
                'unknown_total'            => { 'total' => 0, 'percent' => 0, 'percent_of_known' => 0 },

                'critical_scheduled'       => { 'total' => 0, 'percent' => 0, 'percent_of_known' => 0 },
                'critical_unscheduled'     => { 'total' => 0, 'percent' => 0, 'percent_of_known' => 0 },
                'critical_total'           => { 'total' => 0, 'percent' => 0, 'percent_of_known' => 0 },

                'undetermined_not_running' => { 'total' => 0, 'percent' => 0, 'percent_of_known' => 0 },
                'undetermined_insufficent' => { 'total' => 0, 'percent' => 16.129, 'percent_of_known' => 0 },
                'undetermined_total'       => { 'total' => 0, 'percent' => 0, 'percent_of_known' => 0 },

                'all_total'                => { 'total' => 604800, 'percent' => 0, 'percent_of_known' => 0 },
            }
        }
    }
};

my $ma = Monitoring::Availability->new(
    'log_array'                     => $logs,
    'services'                      => ['host' => 'n0_test_host_000', 'service' => 'n0_test_random_04' ],
    'start'                         => 1262894050,
    'end'                           => 1263498850,
    'backtrack'                     => 4,
    'assumestateretention'          => 'yes',
    'assumeinitialstates'           => 'yes',
    'assumestatesduringnotrunning'  => 'yes',
    'initialassumedhoststate'       => 0,
    'initialassumedservicestate'    => 0,
);
isa_ok($ma, 'Monitoring::Availability', 'create new Monitoring::Availability object');
my $result = $ma->calculate();
is_deeply($result, $expected, 'sample 1 result');
