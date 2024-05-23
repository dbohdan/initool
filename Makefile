DESTDIR=
PREFIX=/usr/local
BINDIR=$(PREFIX)/bin

all: initool test VERSION

initool: initool.mlb stringtrim.sml ini.sml initool.sml
	mlton initool.mlb

initool-static: initool.mlb stringtrim.sml ini.sml initool.sml
	mlton -link-opt -static initool.mlb

VERSION: initool
	./initool version > VERSION

test:
	sh test.sh

clean:
	-rm initool VERSION

install: initool
	mkdir -p $(DESTDIR)$(BINDIR)
	install initool $(DESTDIR)$(BINDIR)
uninstall:
	rm $(DESTDIR)$(BINDIR)/initool

.PHONY: all clean initool-static test install uninstall
