#!/bin/bash
### Script ###############################
[ "${0:0:1}" != "/" ] && _prefix="$(pwd)/"
scpt_dir="$_prefix$(dirname "$0")"
lib_dir="$scpt_dir/zz_lib"
source "$lib_dir/common.sh" || exit 255
cd "$(dirname "$0")"/../ || exit 42
##########################################


if [ -n "$1" -o "$1" = "--help" ]; then
	echo "syntax: $0" >/dev/stderr
	echo "   the repo must be clean when running this script" >/dev/stderr
	echo "   note: --help makes program exit with status 1" >/dev/stderr
	exit 1
fi

"$lib_dir/set_project_version.sh" --targets "LocMapper Linter" --bump-build-version --commit
