echo -- get
$INITOOL get tests/repeat-section.ini bar foo
echo -- get value
$INITOOL get tests/repeat-section.ini bar foo --value-only
echo -- section exists
$INITOOL exists tests/repeat-section.ini bar && echo 1 || echo 0
echo -- key exists
$INITOOL exists tests/repeat-section.ini bar foo && echo 1 || echo 0
echo -- set
$INITOOL set tests/repeat-section.ini bar foo 3
echo -- delete
$INITOOL delete tests/repeat-section.ini bar foo
