#!/bin/bash
### Lib ##################################
[ "${0:0:1}" != "/" ] && _prefix="$(pwd)/"
scpt_dir="$_prefix$(dirname "$0")"
lib_dir="$scpt_dir"
source "$lib_dir/common.sh" || exit 255
##########################################


usage() {
	echo "syntax: $0 [--project path_to_xcodeproj] [--targets target1 --targets target2 ...] [--bump-build-version|--set-build-version new_version] [--set-marketing-version new_marketing_version] ([--force] [--commit]|[--no-commit])" >/dev/stderr
	echo "   exits with status 1 for syntax error, 2 if repo is dirty and force is not set, 3 on xct error, 4 on commit error after xct updated the version of the project, 5 if a dep is not found" >/dev/stderr
	echo "   note: --help makes program exit with status 1 too" >/dev/stderr
	exit 1
}


command -v jq  >/dev/null 2>&1 || { echo "Please install jq (e.g. brew install jq) to use this script" >/dev/stderr; exit 5; }
command -v xct >/dev/null 2>&1 || { echo "Please install xct (e.g. brew install xcode-actions/tap/xct) to use this script" >/dev/stderr; exit 5; }


force=0
commit=-1
xct_options=()

new_build_version=
new_marketing_version=
while [ -n "$1" ]; do
	case "$1" in
		--project)
			shift
			[ -n "$1" ] || usage
			xct_options=("${xct_options[@]}" "--path-to-xcodeproj=$1")
			;;
		--targets)
			shift
			[ -n "$1" ] || usage
			xct_options=("${xct_options[@]}" "--targets=$1")
			;;
		--bump-build-version)
			new_build_version="BUMP"
			;;
		--set-build-version)
			shift
			new_build_version="$1"
			[ -n "$new_build_version" ] || usage
			[ "$new_build_version" != "BUMP" ] || { echo "New version cannot be set to \"BUMP\""; exit 1; }
			;;
		--set-marketing-version)
			shift
			new_marketing_version="$1"
			[ -n "$new_marketing_version" ] || usage
			;;
		--force)
			force=1
			;;
		--commit)
			commit=1
			;;
		--no-commit)
			commit=0
			;;
		--)
			shift
			break
			;;
		*)
			break
			;;
	esac
	shift
done
[ -z "$1" ] || usage


if [ "$commit" = "-1" ]; then
	commit=$((1-force))
fi

test "$force" = "1" || "$lib_dir/is_repo_clean.sh" || exit 1

case "$new_build_version" in
	"BUMP")
		current_build_number="$(xct versions "${xct_options[@]}" --output-format json get-versions | jq -r .reduced_build_version_for_all)" || exit 3
		test "$current_build_number" != "null" || { echo "Cannot get current build number" >/dev/stderr; exit 3; }
		version="$((current_build_number + 1))" || exit 3
		xct versions "${xct_options[@]}" set-build-version "$version" || exit 3
		test "$commit" = "1" && ( "$lib_dir/is_repo_clean.sh" || git commit -am "Bump build number to \"$version\" with xct" ) || exit 4
		;;
	*)
		if [ -n "$new_build_version" ]; then
			xct versions "${xct_options[@]}" set-build-version "$new_build_version" || exit 3
			test "$commit" = "1" && ( "$lib_dir/is_repo_clean.sh" || git commit -am "Set build number to \"$new_build_version\" with xct" ) || exit 4
		fi
		;;
esac
if [ -n "$new_marketing_version" ]; then
	xct versions "${xct_options[@]}" set-marketing-version "$new_marketing_version" || exit 3
	test "$commit" = "1" && ( "$lib_dir/is_repo_clean.sh" || git commit -am "Set marketing version to \"$new_marketing_version\" with xct" ) || exit 4
fi
