#!/usr/bin/env bash
#set -o xtrace
set -o errexit

! [[ "$1" ]] && { echo "usage: $0 NAME" ; exit 1 ; }

_basedir="$(realpath "$(dirname "$0")"/..)"

set -o nounset

if [[ "$1" == "all" ]] ; then
    for recipe in "$_basedir"/recipes/* ; do
        name="$(basename "$recipe")"
        echo "Building $name"
        "$0" "$name"
    done
    exit 0
fi

source "$_basedir"/defaults.sh
source "$_basedir"/recipes/"$1"/info.sh

INSTALLROOT="$_basedir"/"$INSTALLROOT"/"$1"
YUMDBDIR="$_basedir"/"$YUMDBDIR"/"$1"
CACHEDIR="$_basedir"/"$CACHEDIR"/"$RELEASEVER"
OUTDIR="$_basedir"/"$OUTDIR"
REPOCONF="$_basedir"/"$REPOCONF"

mkdir -p "$INSTALLROOT"
mkdir -p "$YUMDBDIR"
mkdir -p "$CACHEDIR"

rpm --dbpath "$YUMDBDIR"/"$1" --initdb

_yumopts=(
    --quiet
    --assumeyes
    --installroot="$(realpath "$INSTALLROOT")"
    --config="$REPOCONF"
    --releasever=$RELEASEVER
    --setopt=cachedir="$(realpath "$CACHEDIR")"
    --setopt=persistdir="$(realpath "$YUMDBDIR")"/var/lib/yum
    --nogpgcheck
)

needinstall=0
needupdate=0

for pkg in "${PACKAGES[@]}" ; do
    if ! rpm --root "$(realpath "$INSTALLROOT")" --query "$pkg" >/dev/null; then
        needinstall=1
        break
    fi
done

yum "${_yumopts[@]}" check-updates
if (( $? == 100 )) ; then
    needupdate=1
fi

if (( needinstall )) ; then
    echo "Installing packages."
    yum "${_yumopts[@]}" install -- "${PACKAGES[@]}"
else
    echo "All packages already installed."
fi

if (( needupdate )) ; then
    echo "Updating packages."
    yum "${_yumopts[@]}" update
else
    echo "All packages up to date."
fi

mkdir -p "$OUTDIR"
_outfile="$OUTDIR"/"$NAME".aci

if [[ -f "$_outfile" ]] && ! (( needinstall || needupdate )) ; then
    exit 0
fi

acbuildend() {
    export EXIT=$?
    acbuild --debug end && exit $EXIT
}
trap acbuildend EXIT

acbuild --debug begin "$INSTALLROOT"

acbuild --debug set-name "$NAME"

[[ "$EXEC" ]] && \
acbuild --debug set-exec "$EXEC"

[[ "$USER" ]] && \
acbuild --debug set-user "$GROUP"

[[ "$GROUP" ]] && \
acbuild --debug set-group "$GROUP"

acbuild --debug write --overwrite "$_outfile"
