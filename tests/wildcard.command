wildcard=_

echo -- get in any section
"$INITOOL" get tests/test.ini "$wildcard" name1
echo -- get, any key
"$INITOOL" get tests/test.ini foo "$wildcard"

echo -- exists in any section
"$INITOOL" exists tests/test.ini "$wildcard" name1 && echo 1 || echo 0
echo -- exists, any key
"$INITOOL" exists tests/test.ini foo "$wildcard" && echo 1 || echo 0

echo -- set in any section
"$INITOOL" set tests/test.ini "$wildcard" name1 HELLO
echo -- set, any key
"$INITOOL" set tests/test.ini foo "$wildcard" HELLO

echo -- delete in any section
"$INITOOL" delete tests/test.ini "$wildcard" name1
echo -- delete, any key
"$INITOOL" delete tests/test.ini foo "$wildcard"
