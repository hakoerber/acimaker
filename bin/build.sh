#!/usr/bin/env bash

! [[ "$1" ]] && { echo "usage: $0 NAME" ; exit 1 ; }

set -o nounset

_basedir="$(readlink -m "$(dirname "$0")"/..)"

if [[ "$1" == "all" ]] ; then
    for recipe in "$_basedir"/recipes/*.recipe ; do
        name="$(basename "${recipe%.*}")"
        echo "Building $name"
        "$0" "$name"
    done
    exit 0
fi

_recipe="$_basedir"/recipes/"$1".recipe
source "$_basedir"/defaults.sh
source "$_recipe"

# check dependencies recursively
_deps=()
set +o nounset
while : ; do
    if [[ "$BASE" ]] ; then
        _deps+=("$BASE")
        _base="$BASE"
        BASE=""
        source "$_basedir"/recipes/"$_base".recipe
    else
        break
    fi
done
set -o nounset

# walk dependecy tree backwards and source all files
for (( i=(${#_deps[@]} - 1) ; i >= 0 ; i-- )) ; do
    _base="${_deps[$i]}"
    source "$_basedir"/recipes/"$_base".recipe
done
source "$_recipe"

INSTALLROOT="$(readlink -m "$_basedir"/"$INSTALLROOT"/"$1")"
CACHEDIR="$(readlink -m "$_basedir"/"$CACHEDIR"/"$RELEASEVER")"
OUTDIR="$(readlink -m "$_basedir"/"$OUTDIR")"
REPOCONF="$(readlink -m "$_basedir"/"$REPOCONF")"

source "$_basedir"/lib/"$DISTRO".sh
source "$_basedir"/lib/acibuild.sh

mkdir -p "$INSTALLROOT"
mkdir -p "$CACHEDIR"
mkdir -p "$OUTDIR"

needrebuild
rebuild=$(( ! $? ))

if (( rebuild )) ; then
    buildrootfs
else
    echo "No rebuild of rootfs necessary."
fi

_outfile="$OUTDIR"/"$NAME".$(date +%Y-%m-%dT%H:%M:%S).aci
_latestfile="$OUTDIR"/"$NAME".latest.aci

if (( ! rebuild )) ; then
    if [[ -e "$_latestfile" ]] ; then
        ln --verbose --symbolic --relative --logical "$_latestfile" "$_outfile"
    else
        rebuild=1
    fi
fi

if (( rebuild )) ; then
    buildaci
    ln --verbose --symbolic --relative --force "$_outfile" "$_latestfile"
fi
