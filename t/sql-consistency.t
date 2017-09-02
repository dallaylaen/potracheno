#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use File::Basename qw(dirname);

my $dir = dirname($0)."/../sql";
opendir( my $dfd, $dir )
    or die "Failed to read $dir: $!";
my @files = grep { /^potracheno\..*\.sql$/ } readdir($dfd);
closedir $dfd;

my %signatures;
foreach my $f (@files) {
    open my $fd, "<", "$dir/$f"
        or die "Failed to open(r) $dir/$f: $!";
    my %fields;
    my $table;
    while (<$fd>) {
        s#^\s+##;
        if ($table) {
            if (/^\)/) {
                undef $table;
                next;
            };
            /^(\w+)/ or next;
            my $field = $1;
            /UNIQUE/i and $field .= "=1";
            /NOT *NULL/i and $field .= "/0";
            $fields{"$table.$field"}++;
        } else {
            /CREATE TABLE (\w+)/i or next;
            $table = $1;
            note "Found table $table in $f"
        };
    };

    $signatures{$f} = join ";", sort keys %fields;
};

my ($first, @other) = @files;

foreach (@other) {
    is ($signatures{$_}, $signatures{$first}, "files $_ and $first identic");
};

done_testing;
