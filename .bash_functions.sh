function retry {
    "$@"
    while [ $? != 0 ]
    do
        "$@"
    done
}
