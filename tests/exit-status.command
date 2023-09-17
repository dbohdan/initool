echo -- get section, missing section
$INITOOL get tests/test.ini boo >/dev/null && echo success || echo failure

echo -- get key, missing section
$INITOOL get tests/test.ini boo xyz >/dev/null && echo success || echo failure

echo -- get key, missing key
$INITOOL get tests/test.ini boo xyz >/dev/null && echo success || echo failure

echo -- check if section exists, missing section
$INITOOL exists tests/test.ini boo >/dev/null && echo success || echo failure

echo -- check if key exists, missing section
$INITOOL exists tests/test.ini boo xyz >/dev/null && echo success || echo failure

echo -- check if key exists, missing key
$INITOOL exists tests/test.ini boo xyz >/dev/null && echo success || echo failure

echo -- set key, missing section
$INITOOL set tests/test.ini boo name1 foo1 >/dev/null && echo success || echo failure

echo -- set key, missing key
$INITOOL set tests/test.ini foo xyz foo1 >/dev/null && echo success || echo failure

echo -- delete section, missing section
$INITOOL delete tests/test.ini boo >/dev/null && echo success || echo failure

echo -- delete key, missing section
$INITOOL delete tests/test.ini boo xyz >/dev/null && echo success || echo failure

echo -- delete key, missing key
$INITOOL delete tests/test.ini boo xyz >/dev/null && echo success || echo failure
