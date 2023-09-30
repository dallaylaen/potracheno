#!/bin/sh

DIR=$(dirname "$0")
FILES=$(ls "$DIR" | grep -v "\\.")

if [ ! -d './.git/hooks' ]; then
    echo >&2 "$(pwd) is not a git repository, change into one!"
    exit 1
fi

echo linking to $DIR
echo found scripts: $FILES

set -ex

for i in $FILES; do
	ln -frs $DIR/$i ./.git/hooks
done
