#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use Potracheno::Model;

my $t = 1_000_000;
my $str = Potracheno::Model->time2human( $t );
note "1Msec = $str";

is (Potracheno::Model->human2time( $str ), $t, "Round trip");
is (Potracheno::Model->human2time("0.25h"), 15*60, "Default hours");
is (Potracheno::Model->human2time("137"), 137, "No units = seconds");
is (Potracheno::Model->human2time("I wasted 0.25 minutes"), 15
    , "Reads minutes ok");

is (Potracheno::Model->time2human(Potracheno::Model->human2time("60m")),"1h"
    , "Time units compacted");

done_testing;
