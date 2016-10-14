General

##Purpose

**Potracheno** is a [tech debt](https://en.wikipedia.org/wiki/Technical_debt)
issue tracking system ([ITS](https://en.wikipedia.org/wiki/Issue_tracking_system)).

##Naming

*Potracheno* ("потрачено") is a Russian adjective with a meaning 
close to *wasted* or *spent*. 
It became a local meme after being incorrectly used
in *Grand Theft Auto* death scene localization.

## Description

Just like a normal ITS, *Potracheno* has tickets, which in turn have
comments, statuses, and a time tracking facility. [Markdown](/help/markdown)
is supported for both tickets and comments.

However, instead of tracking time spent *fixing* an issue, it rather
tracks time wasted *dealing with it*, aka
[total\_hours\_wasted\_here](http://stackoverflow.com/a/482129/280449).

Also unlike a normal ITS it has *solution proposals* which can be posted
for any issue. Those are just special comments with a time estimate.

## Usage scenario

The intended usage is as follows.
All the inconveniences of the project should be
[posted here](/post), like:

* Poorly written code (each case separately);
* Hard to use APIs;
* Outdated libraries;
* Sloppy or missing internal tools;
* Slow or broken development/testing environment;
* Missing or broken tests;
* etc, etc, etc.

Then, as any developer encounters some of those beasts, he or she should
log the time wasted instead of doing actual work.

As statistics [accumulate](/report/http://localhost:5000/report?status_not=on&status=0&order_by=time_spent_s&order_dir=DESC),
it may become clear which parts of the system should be
rewritten, refactored, or otherwise improved on in the first place,
and how much time is affordable to spend on that.

## BUGS

Lots of them. This product is still under heavy development.

Bug reports are welcome at [https://github.com/dallaylaen/potracheno/issues/new]
(https://github.com/dallaylaen/potracheno/issues/new).

Contributions are welcome at [https://github.com/dallaylaen/potracheno]
(https://github.com/dallaylaen/potracheno).

## COPYRIGHT AND LICENSE

Copyright 2016 [Konstantin S. Uvarin](https://github.com/dallaylae).

UI redesign (c) 2016 by [Pavel Kuptsov](https://github.com/poizon).

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See [http://dev.perl.org/licenses/](http://dev.perl.org/licenses/)
for more information.
 

