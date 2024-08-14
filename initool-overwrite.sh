#! /bin/sh
set -eu

usage() {
    echo "usage: $(basename "$0") command file [arg ...]"
}

help() {
    printf 'Modify the input file with initool.\n\n'
    usage
    printf '\nYou can give the path to initool in the environment variable "INITOOL".\n'
}

for arg in "$@"; do
    if [ "$arg" = "-h" ] || [ "$arg" = "--help" ]; then
        help
        exit 0
    fi
done

if [ $# -lt 2 ]; then
    usage >/dev/stderr
    exit 2
fi

command=$1
file=$2
replace_original=1

if [ "$command" = e ] || [ "$command" = exists ]; then
    replace_original=0
fi

if [ "$file" = - ]; then
    echo 'file must not be "-"' >/dev/stderr
    exit 2
fi

temp=$(mktemp)
clean_up() {
    rm "$temp" 2>/dev/null || true
}
trap clean_up EXIT HUP INT QUIT TERM

"${INITOOL:-initool}" "$@" >"$temp"
status=$?

if [ "$status" -eq 0 ] && [ "$replace_original" -eq 1 ]; then
    mv "$temp" "$file"
else
    exit "$status"
fi
