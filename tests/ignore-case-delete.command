echo -- section
$INITOOL -i delete tests/test.ini FOO name1
echo -- key
$INITOOL -i delete tests/test.ini foo NAME1
echo -- both
$INITOOL --ignore-case delete tests/test.ini FOO NAME1
