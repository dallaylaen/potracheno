#!/usr/bin/env perl

use strict;
use warnings;
use JSON::XS;
use Getopt::Long;
use POSIX qw(setsid);
use IO::Socket::INET;

use FindBin qw($Bin);
use lib "$Bin/lib", "$Bin/local/lib";
use App::Its::Potracheno::Config;

my $root = "$Bin";
my $config_file = "$root/local/potracheno.cfg";
my $app = "$root/bin/potracheno.psgi";
my $server = "plackup";

# getopt here?

my $conf = App::Its::Potracheno::Config->load_config(
    $config_file, ROOT => $root );

$conf = $conf->{server};
$conf->{port}       ||= 5000;
$conf->{access_log} ||= "$root/local/access.log";
$conf->{error_log}  ||= "$root/local/error.log";
$conf->{pidfile}    ||= "$root/local/pid.txt";

my $action = shift;
if (!$action) {
    print "Usage: perl $0 [start|stop|restart]\n";
    exit 0;
};

if ($action eq 'restart' || $action eq 'start') {
    stop() && start();
} elsif ($action eq 'stop' ) {
    stop();
} else {
    die "Unknown action $action";
};

sub start {
    print "Checking $app...\n";
    open my $pipe, "-|", perl => $app;
    local $/;
    my $content = <$pipe>;
    $content =~ /<body>/ or die "Unable to start $app";

    print "Running server...\n";
    my $pid;
    local $SIG{CHLD} = sub { die "Premature exit from child ($pid)" };
    $pid = fork;
    die "Fork failed: $!" unless defined $pid;

    if (!$pid) {
        # CHILD SECTION
        setsid();
        open STDIN, "<", "/dev/null"
            or die "Failed to redirect STDIN: $!";
        open STDOUT, ">>", $conf->{error_log}
            or die "Failed to redirect STDOUT: $!";
        open STDERR, ">>", $conf->{error_log}
            or die "Failed to redirect STDERR: $!";

        exec $server => '--listen' => ":$conf->{port}"
            => '--access-log' => $conf->{access_log}
            => $app
            or die "Exec failed: $!";
        # END CHILD SECTION
    };

    print "Waiting for port $conf->{port}...\n";
    wait_for_port( $conf->{port}, 1 );
    undef $SIG{CHLD};
    open my $fd, ">", $conf->{pidfile}
        or die "Failed to save pid $pid to file $conf->{pidfile}: $!";
    print $fd $pid
        or die "Failed to save pid $pid to file $conf->{pidfile}: $!";
    close $fd
        or die "Failed to save pid $pid to file $conf->{pidfile}: $!";
    print "Start OK\n";
    return 1;
};

sub stop {
    # No pidfile = ok
    -f $conf->{pidfile} or return 1;

    open (my $fd, "<", $conf->{pidfile})
        or die "Failed to read pidfile $conf->{pidfile}: $!";

    my $pid = <$fd>;
    chomp $pid;
    die "Broken pid file $conf->{pidfile}"
        unless $pid =~ /^\d+$/;

    # detect stale pid
    if ([stat $fd]->[9] >= ([stat "/proc/$pid/fd/0"]->[9] || 9**9**9)) {
        print "Killing pid $pid...\n";
        kill INT => $pid
            or die "Failed to send signal: $!";
    } else {
        warn "Stale pid detected in $conf->{pidfile}: $pid";
    };

    print "Waiting for port $conf->{port}...\n";
    wait_for_port( $conf->{port}, 0 );
    unlink $conf->{pidfile};

    print "Stop OK\n";
    return 1;
};

sub wait_for_port {
    my ($port, $on_off) = @_;

    local $SIG{ALRM} = sub { die "Failed to wait for socket to "
        .($on_off ? "start" : "stop") };
    alarm 10;

    while ( 1 ) {
        my $sock = IO::Socket::INET->new(
            Proto => "tcp",
            PeerHost => "localhost",
            PeerPort => $port,
        );
        close $sock if $sock;

        last unless $sock xor $on_off; # sock and on_off must be both true | both false
        sleep 0.01;
    };
    alarm 0;
};
