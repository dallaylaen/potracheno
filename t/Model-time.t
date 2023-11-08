#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use App::Its::Wasted::Model;

my $t = 1_000_000;
my $str = App::Its::Wasted::Model->time2human( $t );
note "1Msec = $str";

is (App::Its::Wasted::Model->human2time( $str ), $t, "Round trip");
is (App::Its::Wasted::Model->human2time("0.25h"), 15*60, "Default hours");
is (App::Its::Wasted::Model->human2time("137"), 137, "No units = seconds");
is (App::Its::Wasted::Model->human2time("I wasted 0.25 minutes"), 15
    , "Reads minutes ok");

is (App::Its::Wasted::Model->time2human(App::Its::Wasted::Model->human2time("60m")),"1h"
    , "Time units compacted");

done_testing;
