echo -- section
$INITOOL -i get tests/test.ini FOO name1
echo -- key
$INITOOL -i get tests/test.ini foo NAME1
echo -- both
$INITOOL --ignore-case get tests/test.ini FOO NAME1
