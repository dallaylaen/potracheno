#!perl

use strict;
use warnings;
use Test::More;
use File::Temp qw(tempfile);

use App::Its::Potracheno::Update;

$SIG{__WARN__} = sub { $_[0] =~ /^INFO/ or fail $_[0]; };

my ($fd, $name) = tempfile(
    "potracheno-t-XXXXXXXXX", SUFFIX => '.pm', UNLINK =>1, TMPDIR=>1 );

print $fd "our \$VERSION = 1.1;\n" or die "Failed to write $name: $!";
close $fd or die "Failed to close $name: $!";

my $upd = App::Its::Potracheno::Update->new(
    update_link => 'file://'.$name,
    interval    => 10000,
    version     => 0.5,
);

my $hash = $upd->permanent_ref;

is_deeply $hash, {}, "Empty hash produced";

ok $upd->is_due, "Update is due";

is_deeply $upd->run_update, { version => '1.1' }, "Update worked";
is_deeply $hash, { version => '1.1' }, "Permanent data saved";

ok !$upd->is_due, "No need to update";

my $upd2 = App::Its::Potracheno::Update->new(
    update_link => 'file://'.$name,
    interval    => 10000,
    version     => 2.5,
);

is_deeply scalar $upd2->run_update, undef, "Update worked < VERSION";
ok !$upd2->is_due, "No need to update";

done_testing;
