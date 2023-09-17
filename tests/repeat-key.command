echo -- get
$INITOOL get tests/repeat-key.ini '' foo

echo -- get value
$INITOOL get tests/repeat-key.ini '' foo --value-only

echo -- exists
$INITOOL exists tests/repeat-key.ini '' foo && echo 1 || echo 0

echo -- set
$INITOOL set tests/repeat-key.ini '' foo 3

echo -- delete
$INITOOL delete tests/repeat-key.ini '' foo
