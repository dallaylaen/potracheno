# NAME

Potracheno is a specialized issue tracker for sizing tech debt impact.

*Potracheno* is a Russian adjective with a literal meaning between
*wasted* and *spent*.
It became a local meme after being incorrectly used in
*GTA* game death scene localization.

# DESCRIPTION

Just like a normal ITS, Potracheno has issues, which in turn have comments and
time tracking facility.
However, instead of tracking time spent on *resolving* an issue,
it tracks time spent *working around it*.

This is supposed to help track down the exact tech debt instances
that slow down and demotivate the team.

# INSTALLATION

On a Unix system:

    git clone <this repository>

    ./bin/install.pl --doit

    plackup cgi/app.psgi

The `install.pl` command will:

* check for missing dependencies;

* create a `local` directory;

* install latest `MVC::Neaf` from github *locally*,
unless such library is already available;

* create a default configuration file at local/potracheno.cfg,
unless it's already there;

* create an empty SQLite DB from template in `sql` directory,
unless a previous config was detected, or database already exists.

No setup is currently available for Windows, though it is planned.
Generally the sequence is as above.
`perl bin\\install.pl --doit --readonly` command will only check for
dependencies, and test database availability.

# DEPENDENCIES

* https://github.com/dallaylaen/perl-mvc-neaf (currently not on CPAN)

* DBI

* DBD::SQLite

# BUGS

Lots of them. This product is still under heavy development, see TODO.

# COPYRIGHT AND LICENSE

Copyright 2016 [Konstantin S. Uvarin](https://github.com/dallaylaen).

This program is free software available under the same terms as Perl itself.
