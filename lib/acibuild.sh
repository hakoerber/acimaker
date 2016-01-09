buildaci() {
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
}
