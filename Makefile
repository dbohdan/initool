all: test VERSION
initool: initool.mlb stringtrim.sml ini.sml initool.sml
	mlton initool.mlb
VERSION: initool.sml
	awk '/val version =/ { v = $$4; gsub(/"/, "", v); print v }' initool.sml > VERSION
test: initool
	sh test.sh
clean:
	-rm initool VERSION
install: initool
	cp initool /usr/local/bin/initool
uninstall:
	rm /usr/local/bin/initool
.PHONY: clean test install uninstall
