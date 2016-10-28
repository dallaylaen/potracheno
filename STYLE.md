# STYLE GUIDE

Please read this file carefully if you are going to contribute.

# CODE STYLE

* Indentation 4 spaces.

* Use Egyptian braces always:

    sub foo {
        return "bar";
    };

* Use 5.8.8 features only (no defined-or, HOW I miss it).

* Try to avoid spaces at end-of-line.

* Try to keep lines <80 chars

# COMMIT

* Modules are versioned as a single real number
`x.yyzz` (major/minor/patch).
Try to increase patch number when committing to master.

* Please run tests before you commit:

    prove -Ilocal/lib -Ilib t

or

    make test

* Please start commit message with a 3+capital letter tag:

    git commit README -m "DOC Documentation fixup"

etc.

* This distribution has .githooks directory if you want real stricture,
but that's optional.

# RELEASE CHECKLIST

Follow the CHECKLIST file in this directory before releasing a new version tag.
It contains some additional quality concerns and smoke test.
