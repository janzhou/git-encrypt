#!/usr/bin/env bash

IFS="
"
echo "recrypt..." >> /tmp/recrypt
[ -n "$GITCRYPT_ALLFILES" ] && (GITCRYPT_AFFECTED_FILES=`git ls-tree --name-only --full-tree -r $GIT_COMMIT` || exit 1)
echo "..." >> /tmp/recrypt


for x in $GITCRYPT_AFFECTED_FILES; do
	echo "recrypt file $x" >> /tmp/recrypt
	cat "$x" | $@ > "$x.tmp" || continue 
	cat "$x.tmp" > "$x" 
	rm -f "$x.tmp"
done

