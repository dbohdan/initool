#!/bin/sh
set -e

dir="$(dirname "$(readlink -f "$0")")"
initool="$dir/initool"
tests="tests/*.command"
temp_file="$(mktemp)"
exit_status="0"
clean_up() {
    rm -f "$temp_file"
}
trap clean_up EXIT INT

for filename in $tests; do
    result_file="$(echo "$filename" | sed -e s/.command/.result/)"
    INITOOL="$initool" sh "$filename" > "$temp_file"
    if ! diff "$result_file" "$temp_file"; then
        # The result differs from what was expected.
        exit_status="1"
        echo "in $filename"
    fi
done

exit "$exit_status"
