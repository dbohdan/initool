# initool

[![Travis CI build status](https://travis-ci.org/dbohdan/initool.svg?branch=master)](https://travis-ci.org/dbohdan/initool)&nbsp;
[![AppVeyor CI build status](https://ci.appveyor.com/api/projects/status/github/dbohdan/initool?branch=master&svg=true)](https://ci.appveyor.com/project/dbohdan/initool)

Initool lets you manipulate the contents of INI files from the command line. It
is a rewrite of an earlier program by the same developer called "iniparse".
Rather than modify INI files in place like iniparse, however, it prints the
modified contents to the standard output.


## Operation

### Usage

* `initool g filename [section [key [--value-only]]]` — retrieve data
* `initool e filename section [key]` — check if a section or a property exists
* `initool d filename section [key]` — delete a section or a property
* `initool s filename section key value` — set a property's value
* `initool v` — print the version number

When given a valid command, initool first reads the INI file `filename` in its
entirety. For the commands `g`, `d`, and `s` it then prints to the standard
output the file's contents with the desired changes. For `e` it reports whether
the section or the property exists through its exit status.

Top-level properties (properties not in any section) are accessed by using an
empty string as the section name. The "exists" command (`e`) with just an empty
string as the argument returns whether or not there are any top-level
properties.

The order in which the properties appear is preserved. A new property is added
after the last property in its section.

Initool understands INI file comments (lines starting with `;` or `#`) in the
input and preserves them in the output. It also preserves empty lines.

### Examples

To modify a file on \*nix, in this case to replace the value of the top-level
property "cache" in the file `settings.ini`, you can do the following:

```sh
initool s settings.ini '' cache 1024 > settings.ini
```

On Windows you should instead redirect initool's output to a temporary file and
then replace the original with it:

```batch
initool s settings.ini "" cache 1024 > temporary.ini
move /y temporary.ini settings.ini
```

To retrieve only the value of a property rather than the whole property
(section, key, and value), use the flag `--value-only`:

```sh
$ initool g tests/test.ini foo name1
[foo]
name1=foo1
$ initool g tests/test.ini foo name1 --value-only
foo1
```

### Whitespace

Initool defines whitespace as any mix of space and tab characters. The leading
and the trailing whitespace around the section name, the key, and the value is
removed from the output.

As a result, the following input files are all equivalent to each other for
initool:

```
[PHP]
short_open_tag=Off
```

```
[PHP]
short_open_tag = Off
```

```
    [PHP]
        short_open_tag   =     Off
```

### Nonexistent sections and properties

How nonexistent sections and properties are handled depends on the command.

| Command | Result | Exit status |
|---------|--------|--------------|
| `g` | With the flag `--value-only` initool produces no output. Without it, a blank line is printed if the section doesn't exist. The section name followed by a blank line is printed if the section exists but the property does not. | 0 |
| `e` | No output. | 0 if the section/property exists and 1 otherwise. |
| `d` | Nothing is removed from the input in the output. | 0 |
| `s` | The section and the property are created if needed. | 0 |

### Line endings

When compiled according to the instructions below, initool will assume line
endings to be LF on *nix and either LF or CR+LF on Windows. To operate on
Windows files from *nix, convert the files' line endings to LF and then back.
You can accomplish this, e.g., [using sed](http://stackoverflow.com/a/2613834).

### Text encodings

Initool is encoding-naive and assumes one character is one byte. It correctly
processes UTF-8-encoded files when given UTF-8 command line arguments but
can't open files in UTF-16 or UTF-32. On Windows it will receive the command
line arguments in the encoding for your system's language for non-Unicode
programs (e.g., [Windows-1252](https://en.wikipedia.org/wiki/Windows-1252)),
which limits what you can do with UTF-8-encoded files.

## Building and installation

### Linux and FreeBSD

Install [MLton](http://mlton.org/) (package `mlton` in Debian, Ubuntu, Fedora,
CentOS and FreeBSD).

Clone the repository and run `make` and `sudo make install` in it. Initool
will be installed in `/usr/local/bin`. Run `sudo make uninstall` to remove it.

### Windows

Prebuilt Windows binaries are available for
[releases](https://github.com/dbohdan/initool/releases) and
[individual commits](https://ci.appveyor.com/project/dbohdan/initool/build/artifacts).

To build initool yourself, install [MoSML](http://mosml.org).

Clone the repository and run `build.cmd` from its directory.

The test suite currently does not work on Windows.

## License

MIT.
