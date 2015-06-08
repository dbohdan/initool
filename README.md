# initool

initool lets you manipulate the contents of INI files from the command line.

It is a rewrite of an earlier program by the author called "iniparse", which
was written in Object Pascal for MS-DOS and later ported to Windows. initool
has a compatible command syntax but its operation differs; rather than modify
INI files in place it outputs the modified file text to standard output. See
below.

## Usage

* `initool g filename [section [key]]` — get data
* `initool d filename section [key]` — delete data
* `initool s filename section key value` — set property value

Top-level properties (properties not stored in a section) are accessed by
using an empty string for the section name.

When given a valid command initool reads the INI file `filename` and outputs
its contents with the desired modifications to the standard output. To modify
a file, in this case to replace the value of the top-level property "cache" in
the file `settings.ini`, you can do the following:

```sh
initool s settings.ini '' cache 1024 > settings.ini
```

To retrieve the value of just one property do

```sh
./initool g tests/test.ini foo name1 | tail -n 1 | cut -d = -f 2
```

When compiled according to the instructions below initool will assume
line endings to be LF on *nix and CR+LF on Windows. To operate on Windows
files from *nix convert their line endings to LF and then back. You can
accomplish this, e.g, with [sed](http://stackoverflow.com/a/2613834/3142963).

## Compiling and installation

### Linux and FreeBSD

Install [MLton](http://mlton.org/) (package `mlton` on Debian, Ubuntu, Fedora,
CentOS and FreeBSD).

Clone the repository and run `make` and `sudo make install` in it. Run `sudo
make uninstall` to remove.

### Windows

Install [MoSML](http://mosml.org).

In the command line prompt run

`"C:\Program Files\mosml\bin\mosmlc.exe" initool.sml -o initool.exe`

or

`"C:\Program Files (x86)\mosml\bin\mosmlc.exe" initool.sml -o initool.exe`

depending on your Windows version.

## License

MIT.
