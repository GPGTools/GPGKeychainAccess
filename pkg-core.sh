#!/usr/bin/env bash
#
# @todo: move to core
#

_pkgBin="packagesbuild"
_cfFile="Makefile.config"
_verString="__VERSION__"

command -v "${_pkgBin}" >/dev/null 2>&1 ||\
  { echo >&2 "I require '${_pkgBin}' but it's not installed.  Aborting."; exit 1; }
[ -f "${_cfFile}" ] ||\
  { echo >&2 "I require file '${_cfFile}' but it does not exit.  Aborting."; exit 1; }

source "${_cfFile}"

[ -n "${pkgProj_core}" ] ||\
  { echo >&2 "I require environment variable 'pkgProj_core' to be set but it's not.  Aborting."; exit 1; }
[ -f "${pkgProj_core}" ] ||\
  { echo >&2 "I require file '${pkgProj_core}' but it does not exit.  Aborting."; exit 1; }
[ -n "${version}" ] ||\
  { echo >&2 "I require environment variable 'version' to be set but it's not.  Aborting."; exit 1; }

sed "s/${_verString}/${version}/g" "${pkgProj_core}" > "${pkgProj_core}.patched"
"$_pkgBin" "${pkgProj_core}.patched"
rm "${pkgProj_core}.patched"