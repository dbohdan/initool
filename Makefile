inifile: inifile.sml
	mlton inifile.sml
test: inifile
	sh test.sh
clean:
	rm inifile
install: inifile
	cp inifile /usr/local/bin/inifile
uninstall:
	rm /usr/local/bin/inifile
.PHONY: clean test install uninstall
.POSIX:
