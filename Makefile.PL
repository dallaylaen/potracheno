use 5.006;
use strict;
use warnings FATAL => 'all';
use ExtUtils::MakeMaker;

use File::ShareDir::Install;
File::ShareDir::Install::install_share( module => "App::Its::Potracheno" => "share" );

WriteMakefile(
    NAME             => 'App::Its::Potracheno',
    AUTHOR           => q{Konstantin S. Uvarin <khedin@gmail.com>},
    VERSION_FROM     => 'lib/App/Its/Potracheno.pm',
    ABSTRACT_FROM    => 'lib/App/Its/Potracheno.pm',
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
        'MVC::Neaf'      => 0.19,
        'DBD::SQLite'    => 0,
        'Template'       => 0,
        'Text::Markdown' => 0,
        'LWP::UserAgent' => 0,
        'JSON::XS'       => 0,
        'LWP::Protocol::https' => 0,
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => 'App-Its-Potracheno-*' },
);


package MY;
use File::ShareDir::Install 'postamble';
