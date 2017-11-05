package App::Its::Potracheno;

use strict;
use warnings;

our $VERSION = 0.12;

=head1 NAME

App::Its::Potracheno - a technical debt assessment tool.

=head1 DESCRIPTION

Potracheno is a technical debt tracker similar to a normal gubtracker.
However, instead of tracking time spent on resolving an issue,
it tracks time wasted by the team because of it.

=head1 SYNOPSIS

    plackup -MApp::Its::Potracheno -e 'run("/my/config");'

    perl -MApp::Its::Potracheno -e 'print get_schema_sqlite();'

Here C</my/config> is a L<App::Its::Potracheno::Config> config file,
but migration to C<Config::Gitlike> planned.

=head1 FUNCTIONS

All functions are exported by default for brevity.

=cut

use Carp;
use URI::Escape;
use Data::Dumper;
use POSIX qw(strftime);
use Digest::MD5 qw(md5_base64);
use Encode;
use File::Basename qw(dirname);
use File::ShareDir qw(module_dir);

use parent 'Exporter';
our @EXPORT = qw(run get_schema_mysql get_schema_sqlite);

use MVC::Neaf 0.17;
use MVC::Neaf qw(:sugar neaf_err);
use MVC::Neaf::X::Form;
use MVC::Neaf::X::Form::Data;
use App::Its::Potracheno::Model;
use App::Its::Potracheno::Config; # TODO replace ->config::gitlike
use App::Its::Potracheno::Update;

=head2 run( \%config || $config_file )

Parse config, initialize model (L<App::Its:Potracheno::Model & friends),
return a PSGI app subroutine.

=cut

our $CONFIG;
sub run {
    croak "Usage: ".__PACKAGE__."::run( 'config_file' );"
        unless @_ == 1;

    local $CONFIG = shift;
    my $app = do 'App/Its/Potracheno/Routes.pm';

    croak "Failed to load App/Its/Potracheno/Routes.pm: "
        .($@ || $! || "unknown reason")
            unless ref $app eq 'CODE';

    # return $app;
    neaf->run;
}; # sub run ends here

=head2 get_schema_sqlite()

=head2 get_schema_mysql()

Use these functions to fetch database schema:

    perl -MApp::Its::Potracheno -we 'print get_schema_sqlite()' | sqlite3 base.sqlite

=cut

sub get_schema_sqlite {
    App::Its::Potracheno::Model->get_schema_sqlite;
};

sub get_schema_mysql {
    App::Its::Potracheno::Model->get_schema_mysql;
};


1;
