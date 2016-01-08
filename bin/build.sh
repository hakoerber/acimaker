#!/usr/bin/env bash
set -o errexit

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

mkdir -p "$INSTALLROOT"
mkdir -p "$CACHEDIR"
mkdir -p "$OUTDIR"

_yumopts=(
    --assumeyes
    --installroot="$INSTALLROOT"
    --config="$REPOCONF"
    --releasever=$RELEASEVER
    --setopt=cachedir="$CACHEDIR"
    --setopt=tsflags=nodocs
    --setopt=reposdir=
    --setopt=clean_requirements_on_remove=yes
    --setopt=requires_policy=strong
    --nogpgcheck
)

_rpmopts=(
    --quiet
    --root "$INSTALLROOT"
)

_clean=(
    /var/log/yum.log
    /dev/null
)

explicit_installed=($(
    repoquery \
    --installroot="$INSTALLROOT" \
    --installed \
    --all \
    --queryformat '%{n}|%{yumdb_info.reason}' \
    | awk -F '|' '{if ($2 == "user") print $1}'
))

needinstall=0
needupdate=0
needremove=0

for pkg in "${PACKAGES[@]}" ; do
    if ! rpm "${_rpmopts[@]}" --query "$pkg" ; then
        needinstall=1
        break
    fi
done

for installedpkg in "${explicit_installed[@]:-}" ; do
    unnecessary=1
    for pkg in "${PACKAGES[@]}" ; do
        if [[ "$installedpkg" == "$pkg" ]] ; then
            unnecessary=0
            break
        fi
    done
    if (( unnecessary )) ; then
        needremove=1
    fi
done

yum "${_yumopts[@]}" check-updates
if (( $? == 100 )) ; then
    needupdate=1
fi

for file in "${_clean[@]}" ; do
    file="$INSTALLROOT"/"$file"
    if [[ -e "$file" ]] ; then
        rm "$file"
    fi
done

rebuild=$(( needinstall || needupdate || needremove ))

if (( rebuild )) ; then
    rm -rf "$INSTALLROOT"
    rpm "${_rpmopts[@]}" --initdb
    yum "${_yumopts[@]}" install -- "${PACKAGES[@]}"
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
    acbuildabort() {
        _exit=$?
        if [[ -e "$_outfile" ]] ; then
            rm "$_outfile"
        fi
        acbuild --debug end && exit $_exit
    }
    trap acbuildabort EXIT

    acbuild --debug begin "$INSTALLROOT"

    acbuild --debug set-name "$NAME"

    [[ "$EXEC" ]] && \
    acbuild --debug set-exec "$EXEC"

    [[ "$USER" ]] && \
    acbuild --debug set-user "$GROUP"

    [[ "$GROUP" ]] && \
    acbuild --debug set-group "$GROUP"

    acbuild --debug write --overwrite "$_outfile"
    acbuild --debug end

    trap - EXIT

    ln --verbose --symbolic --relative --force "$_outfile" "$_latestfile"
fi
