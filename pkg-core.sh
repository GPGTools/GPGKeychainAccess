#!/usr/bin/env bash
#
# @todo: move to core
#

_pkgBin="packagesbuild"
_cfFile="Makefile.config"
_verString="__VERSION__"
_buildString="__BUILD__"

#@todo: to be moved to gpgtools_core.sh
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
[ -n "${pkgProj_corename}" ] ||
	errExit "I require environment variable 'pkgProj_corename' to be set but it's not.  Aborting."
[ -n "${pkgProj_dir}" ] ||
	errExit "I require environment variable 'pkgProj_dir' to be set but it's not.  Aborting."
[ -d "${pkgProj_dir}" ] ||
	errExit "I require directory '${pkgProj_dir}' but it does not exit.  Aborting."
[ -n "${version}" ] ||
	errExit "I require environment variable 'version' to be set but it's not.  Aborting."
[ -n "${build_dir}" ] ||
	errExit "I require environment variable 'build_dir' to be set but it's not.  Aborting."
[ -d "${build_dir}" ] ||
	errExit "I require directory '${build_dir}' but it does not exit.  Aborting."
[ -n "${build_version}" ] ||
	errExit "I require environment variable 'build_version' to be set but it's not.  Aborting."

cp "${pkgProj_dir}"/* "${build_dir}"
sed -i "" "s/${_verString}/${version}/g" "${build_dir}/${pkgProj_corename}"
sed -i "" "s/${_buildString}/${build_version}/g" "${build_dir}/${pkgProj_corename}"

"$_pkgBin" "${build_dir}/${pkgProj_corename}"

