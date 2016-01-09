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

# return 0 when rebuild necessary
# return 1 otherwise
needrebuild() {
    explicit_installed=($(
        repoquery \
        --installroot="$INSTALLROOT" \
        --installed \
        --all \
        --queryformat '%{n}|%{yumdb_info.reason}' \
        | awk -F '|' '{if ($2 == "user") print $1}'
    ))

    local needinstall=0
    local needupdate=0
    local needremove=0

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
    return $(( ! rebuild ))
}

buildrootfs() {
    rm -rf "$INSTALLROOT"
    rpm "${_rpmopts[@]}" --initdb
    yum "${_yumopts[@]}" install -- "${PACKAGES[@]}"
}
