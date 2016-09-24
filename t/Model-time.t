#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use Potracheno::Model;

my $t = 1_000_000;
my $str = Potracheno::Model->time2human( $t );
note "1Msec = $str";

is (Potracheno::Model->human2time( $str ), $t, "Round trip");
is (Potracheno::Model->human2time(0.25), 15*60, "Default hours");
is (Potracheno::Model->human2time("I wasted 0.25 minutes"), 15
    , "Reads minutes ok");

done_testing;
