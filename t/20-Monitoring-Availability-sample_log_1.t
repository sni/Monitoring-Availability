#!/usr/bin/env perl

#########################

use strict;
use Test::More tests => 3;
use Data::Dumper;

use_ok('Monitoring::Availability');

#########################

my $log_livestatus = [
];

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
    'log_livestatus'                => $log_livestatus,
    'services'                      => [{'host' => 'n0_test_host_000', 'service' => 'n0_test_random_04'}],
    'start'                         => 1262894050,
    'end'                           => 1263498850,
);
is_deeply($result, $expected, 'sample 1 result');

__DATA__
