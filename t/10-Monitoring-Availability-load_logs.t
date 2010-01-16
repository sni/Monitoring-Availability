#!/usr/bin/env perl

#########################

use strict;
use Test::More tests => 48;
use Data::Dumper;
use File::Temp qw/ tempfile tempdir /;

use_ok('Monitoring::Availability');

#########################

my $expected = [
    { 'time' => '1263423600', 'type' => 'LOG ROTATION' },
    { 'time' => '1263423600', 'type' => 'LOG VERSION' },
    { 'time' => '1263423600', 'type' => 'CURRENT HOST STATE', 'state' => 0, 'host_name' => 'n0_test_host_001', 'hard' => 1 },
    { 'time' => '1263423600', 'type' => 'CURRENT SERVICE STATE', 'state' => 0, 'host_name' => 'n0_test_host_000',  'service_description' => 'n0_test_random_00', 'hard' => 1 },
    { 'time' => '1263455830', 'type' => 'Auto-save of retention data completed successfully.'  },
    { 'time' => '1263458022', 'type' => 'Caught SIGTERM, shutting down...', 'start' => 0 },
    { 'time' => '1263458024', 'type' => 'Successfully shutdown... (PID=10280)' },
    { 'time' => '1263458025', 'type' => 'livestatus' },
    { 'time' => '1263458026', 'type' => 'Event broker module \'/opt/projects/git/check_mk/livestatus/src/livestatus.o\' deinitialized successfully.' },
    { 'time' => '1263458059', 'type' => 'Nagios 3.2.0 starting... (PID=3382)', 'start' => 1 },
    { 'time' => '1263458059', 'type' => 'Local time is Thu Jan 14 09:34:19 CET 2010' },
    { 'time' => '1263458059', 'type' => 'LOG VERSION' },
    { 'time' => '1263458059', 'type' => 'livestatus' },
    { 'time' => '1263458059', 'type' => 'Event broker module \'/opt/projects/git/check_mk/livestatus/src/livestatus.o\' initialized successfully.' },
    { 'time' => '1263458060', 'type' => 'Finished daemonizing... (New PID=3387)' },
    { 'time' => '1263458061', 'type' => 'SERVICE DOWNTIME ALERT', 'host_name' => 'n0_test_host_004',  'service_description' => 'n0_test_critical_18', 'start' => 1 },
    { 'time' => '1262960576', 'type' => 'Warning' },
    { 'time' => '1262959921', 'type' => 'SERVICE ALERT', 'state' => 3, 'host_name' => 'n0_test_host_029',  'service_description' => 'n0_test_unknown_00', 'hard' => 1 },
    { 'time' => '1262959921', 'type' => 'SERVICE NOTIFICATION' },
    { 'time' => '1262959926', 'type' => 'HOST ALERT', 'state' => 0, 'host_name' => 'n0_test_host_188', 'hard' => 0 },
    { 'time' => '1262959926', 'type' => 'HOST ALERT', 'state' => 2, 'host_name' => 'n0_test_host_199', 'hard' => 0 },
];

my $ma = Monitoring::Availability->new();
isa_ok($ma, 'Monitoring::Availability', 'create new Monitoring::Availability object');

####################################
# try logs, line by line
my $x = 0;
my $logs;
while(my $line = <DATA>) {
    $logs .= $line;
    $ma->_reset_log_store;
    my $rt = $ma->_read_logs_from_string($line);
    is($rt, 1, '_read_logs_from_string rc') or fail_out($x, $line, $ma);
    is_deeply($ma->{'logs'}->[0], $expected->[$x], 'reading logs from string') or fail_out($x, $line, $ma);
    $x++;
}

####################################
# write logs to temp file and load it
my($fh,$filename) = tempfile(CLEANUP => 1);
print $fh $logs;
close($fh);

$ma->_reset_log_store;
my $rt = $ma->_read_logs_from_file($filename);
is($rt, 1, '_read_logs_from_file rc');
is_deeply($ma->{'logs'}, $expected, 'reading logs from file');

####################################
# write logs to temp dir and load it
my $dir = tempdir( CLEANUP => 1 );
open(my $logfile, '>', $dir.'/monitoring.log') or die('cannot write to '.$dir.'/monitoring.log: '.$!);
print $logfile $logs;
close($logfile);

$ma->_reset_log_store;
my $rt = $ma->_read_logs_from_dir($dir);
is($rt, 1, '_read_logs_from_dir rc');
is_deeply($ma->{'logs'}, $expected, 'reading logs from dir');



####################################
# fail and die with debug output
sub fail_out {
    my $x    = shift;
    my $line = shift;
    my $ma   = shift;
    diag('line: '.Dumper($line));
    diag('got : '.Dumper($ma->{'logs'}->[0]));
    diag('exp : '.Dumper($expected->[$x]));
    BAIL_OUT('failed');
}


__DATA__
[1263423600] LOG ROTATION: DAILY
[1263423600] LOG VERSION: 2.0
[1263423600] CURRENT HOST STATE: n0_test_host_001;UP;HARD;1;n0_test_host_001 (checked by mo) OK: ok hostcheck
[1263423600] CURRENT SERVICE STATE: n0_test_host_000;n0_test_random_00;OK;HARD;1;n0_test_host_000 (checked by mo) OK: random n0_test_random_00 ok
[1263455830] Auto-save of retention data completed successfully.
[1263458022] Caught SIGTERM, shutting down...
[1263458024] Successfully shutdown... (PID=10280)
[1263458025] livestatus: Main thread + 10 client threads have finished
[1263458026] Event broker module '/opt/projects/git/check_mk/livestatus/src/livestatus.o' deinitialized successfully.
[1263458059] Nagios 3.2.0 starting... (PID=3382)
[1263458059] Local time is Thu Jan 14 09:34:19 CET 2010
[1263458059] LOG VERSION: 2.0
[1263458059] livestatus: successfully finished initialization
[1263458059] Event broker module '/opt/projects/git/check_mk/livestatus/src/livestatus.o' initialized successfully.
[1263458060] Finished daemonizing... (New PID=3387)
[1263458061] SERVICE DOWNTIME ALERT: n0_test_host_004;n0_test_critical_18;STARTED; Service has entered a period of scheduled downtime
[1262960576] Warning: The check of host 'n0_test_host_058' looks like it was orphaned (results never came back).  I'm scheduling an immediate check of the host...
[1262959921] SERVICE ALERT: n0_test_host_029;n0_test_unknown_00;UNKNOWN;HARD;3;n0_test_host_029 (checked by mo) UNKNOWN: unknown n0_test_unknown_00
[1262959921] SERVICE NOTIFICATION: test_contact;n0_test_host_029;n0_test_unknown_00;UNKNOWN;notify-service;n0_test_host_029 (checked by mo) UNKNOWN: unknown n0_test_unknown_00
[1262959926] HOST ALERT: n0_test_host_188;UP;SOFT;2;mo FLAP: flap hostcheck up
[1262959926] HOST ALERT: n0_test_host_199;UNREACHABLE;SOFT;3;n0_test_host_199 (checked by mo) DOWN: random hostcheck: parent host state: DOWN
