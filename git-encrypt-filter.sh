#!/usr/bin/env bash

IFS="
"

_debug() {
	[ -z "$GITCRYPTDEBUG" ] || echo -e "${1}"
}

_debug ""
[ -n "$GITCRYPT_ALLFILES" ] && _debug "  == [filter] ALL files"

if [ -n "$GITCRYPT_ALLFILES" ]; then
	GITCRYPT_AFFECTED_FILES=`git ls-tree --name-only --full-tree -r $GIT_COMMIT` || exit 1
fi

for x in $GITCRYPT_AFFECTED_FILES; do
	cmd="cat \"$x\" | $@ > \"$x.tmp\""
	_debug "    * $cmd"
	eval $cmd || continue 
	cat "$x.tmp" > "$x" 
	rm -f "$x.tmp"
done

