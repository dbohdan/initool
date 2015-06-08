initool: initool.sml
	mlton initool.sml
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
