#!/bin/sh
set -e

dir="$(dirname "$(readlink -f $0)")"
inifile="$dir/inifile"
tests="tests/*.command"
temp_file="$(mktemp)"
trap "rm -f \"$temp_file\"" 0 1 2 3 15

for filename in $tests; do
    result_file="$(echo "$filename" | sed -e s/.command/.result/)"
    INIFILE="$inifile" sh "$filename" > "$temp_file"
    diff "$result_file" "$temp_file" || echo "in $filename"
done
