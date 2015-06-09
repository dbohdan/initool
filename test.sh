#!/bin/sh
set -e

dir="$(dirname "$(readlink -f "$0")")"
initool="$dir/initool"
tests="tests/*.command"
temp_file="$(mktemp)"
exit_status="0"
trap "rm -f \"$temp_file\"" 0 1 2 3 15

for filename in $tests; do
    result_file="$(echo "$filename" | sed -e s/.command/.result/)"
    INITOOL="$initool" sh "$filename" > "$temp_file"
    diff "$result_file" "$temp_file" || echo "in $filename" || exit_status="1"
done

exit "$exit_status"
