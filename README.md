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

    git clone <this repository>
    plackup cgi/app.psgi

Much better guide TBD.

# DEPENDENCIES

https://github.com/dallaylaen/perl-mvc-neaf
DBI
DBD::SQLite

# BUGS

Lots of them.

# COPYRIGHT AND LICENSE

Copyright 2016 [Konstantin S. Uvarin](https://github.com/dallaylaen).

This program is free software available under the same terms as Perl itself.
