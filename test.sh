function main {
    echo "this"
    failure
    echo "that"
}

function failure {
    exit 1
}

main