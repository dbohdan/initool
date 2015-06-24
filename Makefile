initool: initool.mlb stringtrim.sml ini.sig ini.sml initool.sml VERSION
	mlton initool.mlb
VERSION: initool.sml
	awk '/val version =/ { v = $$4; gsub(/"/, "", v); print v }' initool.sml > VERSION
test: initool
	sh test.sh
clean:
	rm initool
install: initool
	cp initool /usr/local/bin/initool
uninstall:
	rm /usr/local/bin/initool
.PHONY: clean test install uninstall
.POSIX:
