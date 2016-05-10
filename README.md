# initool

[![Travis CI build status](https://travis-ci.org/dbohdan/initool.svg?branch=master)](https://travis-ci.org/dbohdan/initool)&nbsp;
[![AppVeyor CI build status](https://ci.appveyor.com/api/projects/status/github/dbohdan/initool?branch=master&svg=true)](https://ci.appveyor.com/project/dbohdan/initool)

initool lets you manipulate the contents of INI files from the command line.

It is a rewrite of an earlier program by the author called "iniparse", which
was written in Object Pascal for MS-DOS and later ported to Windows. initool
has a backwards compatible command syntax but its operation differs; rather
than modify INI files in place it outputs the modified file text to standard
output. See below.

## Operation

### Usage

* `initool g filename [section [key [--value-only]]]` — retrieve data
* `initool e filename section [key]` — check if a section or a property exists
* `initool d filename section [key]` — delete a section or a property
* `initool s filename section key value` — set a property's value
* `initool v` — print the version number

When given a valid command initool first reads the INI file `filename` in its
entirety. For the commands `g`, `d` and `s` it then outputs the file's
contents with the desired modifications to the standard output. For `e` it
reports whether the section or the property exists through its exit status.

Top-level properties (properties not stored in a section) are accessed by
using an empty string for the section name. The "exist" command (`e`) with an
empty string returns whether or not there are top-level properties.

The order the properties appear in is preserved. A new property is added after
the last property in its section.

initool understands INI file comments (comment lines starting with ";") in the
input and preserves them in the output.

### Examples

To modify a file, in this case to replace the value of the top-level property
"cache" in the file `settings.ini`, you can do the following:

```sh
initool s settings.ini '' cache 1024 > settings.ini
```

To retrieve only the value of a property rather than the property itself use
the option `--value-only`:

```sh
initool g tests/test.ini foo name1 --value-only
```

### Whitespace

initool defines whitespace as any mix of space and tab characters. The leading
and the trailing whitespace around the section name, the key and the value is
removed from the output.

As a result the following input files are all equivalent to each other for
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
| `g` | A blank line is output. | 0 |
| `e` | No output. | 0 if the section/property exists and 1 otherwise. |
| `d` | Nothing is removed from the input in the output. | 0 |
| `s` | The section and the property are created if needed. | 0 |

### Line endings

When compiled according to the instructions below initool will assume line
endings to be LF on *nix and CR+LF on Windows. To operate on Windows files
from *nix convert the files' line endings to LF and then back. You can
accomplish this, e.g, [using sed](http://stackoverflow.com/a/2613834/3142963).

## Compiling and installation

### Linux and FreeBSD

Install [MLton](http://mlton.org/) (package `mlton` on Debian, Ubuntu, Fedora,
CentOS and FreeBSD).

Clone the repository and run `make` and `sudo make install` in it. initool
will be installed in `/usr/local/bin`. Run `sudo make uninstall` to remove it.

### Windows

Install [MoSML](http://mosml.org).

Clone the repository and run `build.cmd` from its directory.

The test suite currently does not work on Windows.

## License

MIT.
