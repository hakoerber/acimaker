#!/usr/bin/env bash

! [[ "$1" ]] && { echo "usage: $0 NAME" ; exit 1 ; }

set -o nounset

_basedir="$(readlink -m "$(dirname "$0")"/..)"

if [[ "$1" == "all" ]] ; then
    for recipe in "$_basedir"/recipes/* ; do
        name="$(basename "$recipe")"
        echo "Building $name"
        "$0" "$name"
    done
    exit 0
fi

source "$_basedir"/defaults.sh
source "$_basedir"/recipes/"$1"

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
