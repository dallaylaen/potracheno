package App::Its::Wasted;

use strict;
use warnings;

our $VERSION = 0.13;

=head1 NAME

App::Its::Wasted - a technical debt assessment tool.

=head1 DESCRIPTION

Potracheno is a technical debt tracker similar to a normal gubtracker.
However, instead of tracking time spent on resolving an issue,
it tracks time wasted by the team because of it.

=head1 SYNOPSIS

    plackup -MApp::Its::Wasted -e 'run("/my/config");'

    perl -MApp::Its::Wasted -e 'print get_schema_sqlite();'

Here C</my/config> is a L<App::Its::Wasted::Config> config file,
but migration to C<Config::Gitlike> planned.

=head1 FUNCTIONS

All functions are exported by default for brevity.

=cut

use parent 'Exporter';
push our @EXPORT, qw(run get_schema_mysql get_schema_sqlite);

use App::Its::Wasted::Update;

use Carp;
use File::Basename qw(dirname);
use FindBin;
use Cwd qw(abs_path);

use Resource::Silo;

resource root => sub {
        abs_path(dirname $FindBin::RealBin);
    };

resource local_dir => sub {
        abs_path(dirname $FindBin::RealBin) . "/local";
    };

resource config_path => sub {
        $_[0]->local_dir . "/potracheno.cfg";
    };

resource config =>
    require         => 'App::Its::Wasted::Config',
    init            => sub {
        my $self = shift;
        my $driver = App::Its::Wasted::Config->new( );
        $driver->load_config(
            $self->config_path,
            ROOT => $self->root,
        );
    };

resource dbh =>
    dependencies    => [ 'config' ],
    require         => [ 'DBI' ],
    init            => sub {
        my $self = shift;
        my $db = $self->config->{db};

        my ($type) = $db->{handle}=~ /dbi:([^:]+)/;
        if ($type eq 'SQLite') {
            return DBI->connect($db->{handle}, $db->{user}, $db->{pass},
                { RaiseError => 1, sqlite_unicode => 1 });
        } elsif($type eq 'mysql') {
            my $dbh = DBI->connect($db->{handle}, $db->{user}, $db->{pass},
                { RaiseError => 1 });
            $dbh->do('SET NAMES utf8;');
            return $dbh;
        };
        # TODO more DB types welcome

        warn "WARN Unknown DB is being used";
        return DBI->connect($db->{handle}, $db->{user}, $db->{pass},
            { RaiseError => 1 });
    };

resource share_dir => sub {
    my $dir = abs_path(__FILE__);
    $dir =~ s#\.pm$##;
    return "$dir/share";
};

resource dir =>
    argument        => qr([a-z_0-9]+),
    dependencies    => [ 'share_dir' ],
    init            => sub {
        my ($self, undef, $suffix) = @_;
        my $dir = $self->share_dir . "/" . $suffix;
        croak "Failed to locate directory $dir"
            unless -d $dir;
        return $dir;
    };

resource model =>
    class           => 'App::Its::Wasted::Model',
    dependencies    => {
        dbh     => 1,
        config  => 1,
    },
    ;

resource auto_update =>
    require         => 'App::Its::Wasted::Update',
    init            => sub {
        my $self = shift;
        App::Its::Wasted::Update->new(
            update_link => "https://raw.githubusercontent.com/dallaylaen/potracheno/master/Changes",
            %{ $self->config->{update} },
        );
    };

=head2 run( \%config || $config_file )

Parse config, initialize model (L<App::Its:Potracheno::Model & friends),
return a PSGI app subroutine.

=cut

sub run {
    require App::Its::Wasted::Routes;
    silo->ctl->override( config_path => shift )
        if @_;

    App::Its::Wasted::Routes->run;
};

=head2 get_schema_sqlite()

=head2 get_schema_mysql()

Use these functions to fetch database schema:

    perl -MApp::Its::Wasted -we 'print get_schema_sqlite()' | sqlite3 base.sqlite

=cut

sub get_schema_sqlite {
    silo->model->get_schema_sqlite;
};

sub get_schema_mysql {
    silo->model->get_schema_mysql;
};


1;
