all: appveyor.yml initool VERSION
initool: initool.mlb stringtrim.sml ini-sig.sml ini.sml initool.sml
	mlton initool.mlb
appveyor.yml: appveyor.yml.in VERSION
	awk 'FNR==NR { VERSION = $$0 } /version:/ { $$0 = "version: \"" VERSION ".{build}\"" } FNR<NR { print }' VERSION appveyor.yml.in > appveyor.yml
VERSION: initool.sml
	awk '/val version =/ { v = $$4; gsub(/"/, "", v); print v }' initool.sml > VERSION
test: initool
	sh test.sh
clean:
	rm appveyor.yml initool VERSION
install: initool
	cp initool /usr/local/bin/initool
uninstall:
	rm /usr/local/bin/initool
.PHONY: clean test install uninstall
