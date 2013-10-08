#!/usr/bin/env perl

#########################

use strict;
use Test::More tests => 16;
use Data::Dumper;
use File::Temp qw/ tempfile tempdir /;

use_ok('Monitoring::Availability::Logs');

#########################

my $expected = [
    { 'time' => '1380826074', 'host_name' => 'Company App', 'type' => 'HOST ALERT', 'state' => 3, hard => 1, plugin_output => 'PENDING - Worst state is PENDING:' },
    { 'time' => '1380826074', 'type' => 'Warning' },
    { 'time' => '1380826074', 'type' => 'Warning' },
    { 'time' => '1380826074', 'host_name' => 'Company App', 'type' => 'HOST ALERT', 'hard' => 1, 'state' => 1, 'plugin_output' => 'WARNING - Worst state is WARNING: Webserver' },
    { 'time' => '1380826074', 'host_name' => 'Company App', 'type' => 'HOST ALERT', 'hard' => 1, 'state' => 3, 'plugin_output' => 'UNKOWN - Worst state is UNKOWN: Application Server' },
];

my $mal = Monitoring::Availability::Logs->new();
isa_ok($mal, 'Monitoring::Availability::Logs', 'create new Monitoring::Availability::Logs object');

####################################
# try logs, line by line
my $x = 0;
my $logs;
while(my $line = <DATA>) {
    $logs .= $line;
    $mal->{'logs'} = [];
    my $rt = $mal->_store_logs_from_string($line);
    is($rt, 1, '_store_logs_from_string rc') or fail_out($x, $line, $mal);
    is_deeply($mal->{'logs'}->[0], $expected->[$x], 'reading logs from string') or fail_out($x, $line, $mal);
    $x++;
}

####################################
# write logs to temp file and load it
my($fh,$filename) = tempfile(CLEANUP => 1);
print $fh $logs;
close($fh);

$mal->{'logs'} = [];
my $rt = $mal->_store_logs_from_file($filename);
is($rt, 1, '_store_logs_from_file rc');
is_deeply($mal->{'logs'}, $expected, 'reading logs from file');

####################################
# write logs to temp dir and load it
my $dir = tempdir( CLEANUP => 1 );
open(my $logfile, '>', $dir.'/monitoring.log') or die('cannot write to '.$dir.'/monitoring.log: '.$!);
print $logfile $logs;
close($logfile);

$mal->{'logs'} = [];
$rt = $mal->_store_logs_from_dir($dir);
is($rt, 1, '_store_logs_from_dir rc');
is_deeply($mal->{'logs'}, $expected, 'reading logs from dir');



####################################
# fail and die with debug output
sub fail_out {
    my $x    = shift;
    my $line = shift;
    my $mal  = shift;
    diag('line: '.Dumper($line));
    diag('got : '.Dumper($mal->{'logs'}->[0]));
    diag('exp : '.Dumper($expected->[$x]));
    BAIL_OUT('failed');
}


__DATA__
[1380826074] HOST ALERT: Company App;(unknown);HARD;1;PENDING - Worst state is PENDING:
[1380826074] Warning: Check result queue contained results for service 'Webserver' on host 'Company App', but the service could not be found!  Perhaps you forgot to define the service in your config files?
[1380826074] Warning: Check result queue contained results for service 'Webserver' on host 'Company App', but the service could not be found!  Perhaps you forgot to define the service in your config files?
[1380826074] HOST ALERT: Company App;DOWN;HARD;1;WARNING - Worst state is WARNING: Webserver
[1380826074] HOST ALERT: Company App;(unknown);HARD;1;UNKOWN - Worst state is UNKOWN: Application Server
