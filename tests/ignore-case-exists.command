echo -- section
$INITOOL -i exists tests/test.ini FOO name1 && echo 1 || echo 0
echo -- key
$INITOOL -i exists tests/test.ini foo NAME1 && echo 1 || echo 0
echo -- both
$INITOOL --ignore-case exists tests/test.ini FOO NAME1 && echo 1 || echo 0
echo -- wrong section
$INITOOL --ignore-case exists tests/test.ini blah NAME1 && echo 1 || echo 0
echo -- wrong key
$INITOOL --ignore-case exists tests/test.ini FOO blah && echo 1 || echo 0
