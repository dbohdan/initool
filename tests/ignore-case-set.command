echo -- section
"$INITOOL" -i set tests/sql.ini 'SQL CUSTOMERBYID' Sql HELLO
echo -- key
"$INITOOL" -i set tests/sql.ini 'sql CustomerById' SQL HELLO
echo -- both
"$INITOOL" --ignore-case set tests/sql.ini 'SQL CUSTOMERBYID' SQL HELLO
echo -- new key
"$INITOOL" --ignore-case set tests/sql.ini 'SQL CUSTOMERBYID' foo bar
