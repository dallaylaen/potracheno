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
it tracks time wasted *living with it*.

This is supposed to help track down the exact tech debt instances
that slow down and demotivate the team.

Features:

* users, issues, comments, and time tracking

* solution proposals with time estimate

* report showing issues with various properties

* issue & comment search (SLQ-based, search engine planned)

* markdown support for issues & comments, editing issues

* DB migration script; MySQL, sqlite support

Planned:

* Versioned editing of comments & issues

* Ready to go solution report

* Watching & notifications

* Comment replies

# INSTALLATION

On a Unix system:

    git clone <this repository>

    perl Install.PL --install

    plackup cgi/app.psgi

The `Install.PL` command will:

* check for missing dependencies;

* create a `local` directory;

* install latest `MVC::Neaf` from github *locally*,
unless such library is already available;

* create a default configuration file at local/potracheno.cfg,
unless it's already there;

* create an empty SQLite DB from template in `sql` directory,
unless a previous config was detected, or database already exists.

No setup is currently available for Windows, though it is planned.
Generally the sequence is as described above.
`perl Install.PL --check` command will assist by checking dependencies.

If **sqlite** which comes by default is not enough due to high load or other
reasons, a **MySQL** DB scheme is also available in `sql/` directory, as well
as a DB migration script (`bin/migrate --help`).
Postgresql support is planned in the future. Patches welcome.

# DEPENDENCIES

* https://github.com/dallaylaen/perl-mvc-neaf (currently not on CPAN)

* DBI

* DBD::SQLite

# BUGS

Lots of them. This product is still under heavy development, see TODO.

# COPYRIGHT AND LICENSE

Copyright 2016 [Konstantin S. Uvarin](https://github.com/dallaylaen).

This program is free software available under the same terms as Perl itself.
