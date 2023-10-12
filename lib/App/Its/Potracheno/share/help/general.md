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
comments, statuses, and a time tracking facility.

However, instead of tracking time spent *fixing* an issue, it rather
tracks time wasted *dealing with it*, aka
[total\_hours\_wasted\_here](http://stackoverflow.com/a/482129/280449).

Also unlike a normal ITS it has *solution proposals* which can be posted
for any issue. Those are just special comments with a time estimate.

## Usage

Whenever you *feel* that an issue with the product under development is slowing
you down, post it here and log time spent because of it. Try and *measure*
the real impact, and let solution estimates accumulate.

### Posting an issue

Use [Add issue](/post) link to post new issues.

Both summary and description are required. [Markdown](/help/markdown)
is used for description.

The button "save" will appear on preview page, however, it would generate
a *new* preview instead of saving if any data in the form was changed.
Same goes for editing an issue.

### Logging time

Post time as 1w 2d 3h 4m 5s. "I wasted 10 minutes on this" will also work.

Post comments in markdown (no preview or edit, so be careful).
Optionally you can change status of the issue.

If neither time nor comment are filled and the status wasn't changed,
nothing will happen.

### Proposing solution

Select "Fix estimate" instead of "time spent" and post a comment.
Time (in the same format) is **required** this time.

### Watching issues

The "watch/unwatch" button adds issue to your favourites.

Go to [My feed](/feed) to see ALL comments and solutions (but not time
entries) on the issues you watch.

No e-mail integration currently exists, so this is the only way
to get feedback for now.

### Browsing issues

Go to [Browse](/browse) to get report on recent issues.

A form with a lot of criteria allows to select issue type you want.
Dates have to be entered manually in yyyy-mm-dd format.

In **solution ready to go** mode (see *--select solution--* dropdown),
only issues having wasted time count exceeding minimal fix estimate
by a factor of Pi are shown.
Pi value can be adjusted if needed. Default is of course equal to 3.1415....

### Browsing tags

Each issue may have zero or more tags, which are shown below the description.
Tags are there to categorize issues.

Go to [tag search](/stats) to get tag and overall statistics.

### Issue search

Although search string is present at the top, it barely works.
Please wait for Sphinx/Lucene support to be added, or
[send patches](https://github.com/dallaylaen/potracheno).

Search is known to break unicode under MySQL. No fix exists yet.

## BUGS

Lots of them. This product is still under heavy development.

Bug reports are welcome at
[https://github.com/dallaylaen/potracheno/issues/new](https://github.com/dallaylaen/potracheno/issues/new).

* Password recovery needed;

* Email integration needed;

* OAuth support needed;

* JS calendar wanted;

* Normal search wanted;

* Refactoring of model class wanted.

Contributions are welcome at
[https://github.com/dallaylaen/potracheno](https://github.com/dallaylaen/potracheno).

## COPYRIGHT AND LICENSE

Copyright (c) 2016 [Konstantin S. Uvarin](https://github.com/dallaylaen).

UI redesign (c) 2016 by [Pavel Kuptsov](https://github.com/poizon).

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See [http://dev.perl.org/licenses/](http://dev.perl.org/licenses/)
for more information.


