all: test VERSION
initool: initool.mlb stringtrim.sml ini.sml initool.sml
	mlton initool.mlb
VERSION: initool
	./initool version > VERSION
test: initool
	sh test.sh
clean:
	-rm initool VERSION
install: initool
	install initool /usr/local/bin/
uninstall:
	rm /usr/local/bin/initool
.PHONY: clean test install uninstall
