#!/bin/sh

DIR=`dirname "$0"`
DIRNAME=`basename "$DIR"`
FILES=`ls "$DIR" | grep -v "\\."`

echo $DIR
echo $FILES

for i in $FILES; do
	echo "ln -s ../../$DIRNAME/$i $DIR/../.git/hooks"
	ln -s ../../$DIRNAME/$i $DIR/../.git/hooks
done
