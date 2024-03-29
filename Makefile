DESTDIR=
PREFIX=/usr/local
BINDIR=$(PREFIX)/bin

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
	mkdir -p $(DESTDIR)$(BINDIR)
	install initool $(DESTDIR)$(BINDIR)
uninstall:
	rm $(DESTDIR)$(BINDIR)/initool
.PHONY: all clean test install uninstall
