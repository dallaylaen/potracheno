#!/usr/bin/env perl

use strict;
use warnings;

use File::Basename qw(dirname);
use lib::relative "../lib", "../local/lib";
use App::Its::Potracheno qw(run);

run( dirname(__FILE__)."/../local/potracheno.cfg" );
