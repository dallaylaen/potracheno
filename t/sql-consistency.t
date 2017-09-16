#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use App::Its::Potracheno;

my %schema = (
    sqlite => get_schema_sqlite(),
    mysql  => get_schema_mysql(),
);

my %signatures;
foreach my $dbtype (keys %schema) {
    my %fields;
    my $table;
    foreach (split /\n/, $schema{$dbtype}) {
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
            note "Found table $table in $dbtype"
        };
    };

    $signatures{$dbtype} = join ";", sort keys %fields;
};

my ($first, @other) = sort keys %schema;

foreach (@other) {
    is ($signatures{$_}, $signatures{$first}, "files $_ and $first identic");
};

done_testing;
