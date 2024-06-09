echo -- case-sensitive, match
"$INITOOL" r tests/php.ini PHP engine On Off && echo success || echo failure

echo -- case-sensitive, no match
"$INITOOL" r tests/php.ini PHP engine on off && echo success || echo failure

echo -- case-insensitive, match
"$INITOOL" -i r tests/php.ini PHP engine on off && echo success || echo failure

echo -- case-insensitive, no match
"$INITOOL" -i r tests/php.ini PHP engine x y && echo success || echo failure

echo -- long command
"$INITOOL" replace tests/sectionless.ini '' a b '' && echo success || echo failure
