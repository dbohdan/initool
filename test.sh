#!/bin/sh
set -eu

rec_readlink() {
    rr_path=$1
    rr_limit=$2
    rr_depth=$3

    if [ "$rr_depth" -ge "$rr_limit" ]; then
        printf \
            'reached recursion limit %u with depth %u when resolving symlink\n' \
            "$rr_limit" \
            "$rr_depth" \
            >/dev/stderr \
            ;
        return 1
    fi

    rr_new=$(readlink "$rr_path") || true

    if [ -z "$rr_new" ] || [ "$rr_new" = "$rr_path" ]; then
        printf '%s' "$rr_path"
        return 0
    fi

    rec_readlink "$rr_new" "$rr_limit" $((rr_depth + 1))
}

me=$(rec_readlink "$0" 10 0)
dir=$(dirname "$me")
cd "$dir"

initool=./initool
tests='tests/*.command'
temp_file=$(mktemp initool-test.XXXXXXXX)
clean_up() {
    rm -f "$temp_file"
}
trap clean_up EXIT HUP INT QUIT TERM

exit_status=0
for filename in $tests; do
    result_file="$(printf '%s' "$filename" | sed -e 's/\.command/.result/')"
    INITOOL="$initool" sh "$filename" >"$temp_file"
    if ! diff "$result_file" "$temp_file"; then
        # The result differs from what was expected.
        exit_status=1
        printf 'in %s\n' "$filename"
    fi
done

exit "$exit_status"
