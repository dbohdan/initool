echo -- Get all
"$INITOOL" g tests/php.ini
echo -- Get [PHP]
"$INITOOL" g tests/php.ini PHP
echo -- Get [test]
"$INITOOL" g tests/php.ini test
echo -- Delete [PHP]
"$INITOOL" d tests/php.ini PHP
echo -- Delete "engine" in [PHP]
"$INITOOL" d tests/php.ini PHP engine
echo -- Delete both keys in [PHP]
"$INITOOL" d tests/php.ini PHP engine | "$INITOOL" d /dev/stdin PHP short_open_tag
echo -- Delete [test]
"$INITOOL" d tests/php.ini test
echo -- Set k=v in [PHP]
"$INITOOL" s tests/php.ini PHP k v
echo -- Set k=v in [test]
"$INITOOL" s tests/php.ini test k v
