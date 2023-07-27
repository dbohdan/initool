$INITOOL get tests/php.ini
echo ---
$INITOOL exists tests/php.ini PHP && echo yes || echo no
echo ---
$INITOOL set tests/php.ini test k v
echo ---
$INITOOL delete tests/php.ini PHP
