#!/usr/bin/env bash
#
# @todo: move to core
#

_pkgBin="packagesbuild"
_cfFile="Makefile.config"
_verString="__VERSION__"



function errExit() {
	if [[ -t 1 ]] ;then
		echo -e "\033[1;31m$* (line ${BASH_LINENO[0]})\033[0m" >&2
	else
		echo "$* (line ${BASH_LINENO[0]})" >&2
	fi
	exit 1
}



command -v "${_pkgBin}" >/dev/null 2>&1 ||
	errExit "I require '${_pkgBin}' but it's not installed.  Aborting."
[ -f "${_cfFile}" ] ||
	errExit "I require file '${_cfFile}' but it does not exit.  Aborting."

source "${_cfFile}"

[ -n "${pkgProj_core}" ] ||
	errExit "I require environment variable 'pkgProj_core' to be set but it's not.  Aborting."
[ -f "${pkgProj_core}" ] ||
	errExit "I require file '${pkgProj_core}' but it does not exit.  Aborting."
[ -n "${version}" ] ||
	errExit "I require environment variable 'version' to be set but it's not.  Aborting."

sed "s/${_verString}/${version}/g" "${pkgProj_core}" > "build/patched.pkgproj"
"$_pkgBin" "build/patched.pkgproj"




