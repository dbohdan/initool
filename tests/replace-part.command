echo -- case-sensitive, match, beginning
"$INITOOL" r tests/replace-part.ini '' key A a && echo success || echo failure

echo -- case-sensitive, match, middle
"$INITOOL" r tests/replace-part.ini '' key 'longer ' '' && echo success || echo failure

echo -- case-sensitive, match, end
"$INITOOL" r tests/replace-part.ini '' key value. string && echo success || echo failure

echo -- case-sensitive, no match, end
"$INITOOL" r tests/replace-part.ini '' key value.. string && echo success || echo failure

echo -- case-insensitive, match, beginning
"$INITOOL" -i r tests/replace-part.ini '' key a a && echo success || echo failure

echo -- case-insensitive, match, middle
"$INITOOL" -i r tests/replace-part.ini '' key 'lOnGeR ' '' && echo success || echo failure

echo -- case-insensitive, match, end
"$INITOOL" -i r tests/replace-part.ini '' key Value. string && echo success || echo failure

echo -- only replace the first occurrence
"$INITOOL" -i r tests/replace-part.ini '' another-key AA GG && echo success || echo failure

echo -- empty text, match
"$INITOOL" -i r tests/replace-part.ini '' empty '' something && echo success || echo failure

echo -- empty text, no match
"$INITOOL" -i r tests/replace-part.ini '' key '' something && echo success || echo failure
