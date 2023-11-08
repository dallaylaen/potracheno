use 5.006;
use strict;
use warnings FATAL => 'all';
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'App::Its::Wasted',
    AUTHOR           => q{Konstantin S. Uvarin <khedin@gmail.com>},
    VERSION_FROM     => 'lib/App/Its/Wasted.pm',
    ABSTRACT_FROM    => 'lib/App/Its/Wasted.pm',
    LICENSE          => 'Artistic_2',
    PL_FILES         => {},
    EXE_FILES        => [qw[
        bin/potracheno-backup.pl
        bin/potracheno-dbtest.pl
        bin/potracheno-lostpass.pl
    ]],
    MIN_PERL_VERSION => 5.008,
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => 0,
    },
    BUILD_REQUIRES => {
        'Test::More' => 0,
    },
    PREREQ_PM => {
        'DBD::SQLite'           => 0,
        'DBI'                   => 0,
        'Getopt::Long'          => 0,
        'JSON::XS'              => 0,
        'LWP::Protocol::https'  => 0,
        'LWP::UserAgent'        => 0,
        'MVC::Neaf'             => 0.29,
        'Resource::Silo'        => 0.10,
        'Template'              => 0,
        'Text::Markdown'        => 0,
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => 'App-Its-Wasted-*' },
);


