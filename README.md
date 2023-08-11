# initool

[![GitHub Actions CI status.](https://github.com/dbohdan/initool/actions/workflows/ci.yml/badge.svg)](https://github.com/dbohdan/initool/actions/workflows/ci.yml)&nbsp;
[![AppVeyor CI status.](https://ci.appveyor.com/api/projects/status/github/dbohdan/initool?branch=master&svg=true)](https://ci.appveyor.com/project/dbohdan/initool)

Initool lets you manipulate the contents of INI files from the command line.
Rather than modify an INI file in place, it prints the modified contents of the
file to standard output.


## Operation

### Usage

* `initool get <filename> [<section> [<key> [-v|--value-only]]]` — retrieve data
* `initool exists <filename> <section> [<key>]` — check if a section or a property exists
* `initool set <filename> <section> <key> <value>` — set a property's value
* `initool delete <filename> <section> [<key>]` — delete a section or a property
* `initool help` — print the help message
* `initool version` — print the version number

Commands can be abbreviated to their first letter: `g`, `e`, `s`, `d`, `v`.
When given a valid command, initool first reads the INI file `filename` in its
entirety. If the filename is `-`, initool reads standard input. For the
commands `get`, `delete`, and `set`, it then prints to standard output the
file's contents with the desired change. For `exists`, it reports whether the
section or the property exists through its exit status.

Top-level properties (properties not in any section) are accessed by using an
empty string as the section name. The `exists` command with just an empty
string as the argument returns whether or not there are any top-level
properties.

The order in which properties appear is preserved. A new property is added
after the last property in its section.

Initool understands INI file comments (lines starting with `;` or `#`) in the
input and preserves them in the output. It also preserves empty lines.

### Examples

#### POSIX

Let's replace the value of the top-level property `cache` in the
file `settings.ini` from a
[POSIX-compatible shell](https://en.wikipedia.org/wiki/Unix_shell). You can
do this on FreeBSD, Linux, and macOS.

```sh
initool set settings.ini '' cache 1024 > settings.ini.new \
&& mv settings.ini.new settings.ini
```

You can pipeline invocations of initool to make multiple changes. Enable `pipefail` in your shell
([support information](https://unix.stackexchange.com/a/654932))
to handle errors correctly.

```sh
set -o pipefail
initool delete settings.ini test \
| initool set - '' cache 1024 > settings.ini.new \
&& mv settings.ini.new settings.ini
```

#### Windows

Now let's replace the value of the top-level property `cache` in the file
`settings.ini` on Windows from the Command Prompt (`cmd.exe`):

```batch
initool set settings.ini "" cache 1024 > settings.ini.new
if %errorlevel% equ 0 move /y settings.ini.new settings.ini
```

You can use pipelines in the Windows Command Prompt. Note that the Command
Prompt has no feature like `pipefail`. The `%errorlevel%` will be that of the
last command in the pipeline, which in this case cannot fail, so an
`%errorlevel%` check would be pointless. This is a reason to avoid pipelines in
batch files.

```batch
initool delete settings.ini test | initool set - "" cache 1024 > settings.ini.new
move /y settings.ini.new settings.ini
```

#### Both

To retrieve only the value of a property rather than the whole property
(the section, key, and value), use the flag `-v` or `--value-only`:

```sh
$ initool get tests/test.ini foo name1
[foo]
name1=foo1
$ initool get tests/test.ini foo name1 --value-only
foo1
```

### Whitespace

Initool defines whitespace as any mix of space and tab characters. Leading
and trailing whitespace around the section name, the key, and the value is
removed from the output.

As a result, the following input files are all equivalent to each other for
initool and produce the same output. The output is identical to the first input.

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

Because of this, you can reformat initool-compatible INI files with the command
`initool get file.ini`.

### Nonexistent sections and properties

How nonexistent sections and properties are handled depends on the command.

* `get`
    * **Result:** With the flag `--value-only`, initool produces no output. Without the flag, initool prints a blank line if the section doesn't exist. Initool prints the section name followed by a blank line if the section exists, but the property does not.
    * **Exit status:** 0.
* `exists`
    * **Result:** No output.
    * **Exit status:** 0 if the section/property exists, 1 if it doesn't.
* `set`
    * **Result:** The section and the property are created as needed.
    * **Exit status:** 0.
* `delete`
    * **Result:** Nothing is removed from the input in the output.
    * **Exit status:** 0.

### Line endings

When compiled according to the instructions below, initool will assume line
endings to be LF on POSIX and either LF or CR+LF on Windows. To operate on
Windows files from POSIX, convert the files' line endings to LF and then back.
You can accomplish this, e.g., [using sed](http://stackoverflow.com/a/2613834).

### Text encodings

Initool is encoding-naive and assumes one character is one byte. It correctly
processes UTF-8-encoded files when given UTF-8 command line arguments but
can't open files in UTF-16 or UTF-32. On Windows, it will receive the command
line arguments in the encoding for your system's language for non-Unicode
programs (e.g., [Windows-1252](https://en.wikipedia.org/wiki/Windows-1252)),
which limits what you can do with UTF-8-encoded files.

## Building and installation

### FreeBSD, MacPorts port

You can install `sysutils/initool` from the FreeBSD ports tree and MacPorts.

### Building on FreeBSD, Linux, macOS

Install [MLton](http://mlton.org/). It is available as the package `mlton` in
Fedora, FreeBSD, Homebrew, MacPorts, and
[other repositories](https://repology.org/project/mlton/versions).
On Debian 12 and Ubuntu 22.04, you will have to build MLton from source.

Clone the repository and run `make` then `sudo make install` in it. Initool
will be installed in `/usr/local/bin`. Run `sudo make uninstall` to remove it.

### Building on Windows

Prebuilt Windows (x86) binaries are attached to
[releases](https://github.com/dbohdan/initool/releases).

To build initool yourself, first install [MoSML](http://mosml.org). The Windows
installer is not available on the offical site due to an antivirus false
positive. I have [mirrored the
installer](https://github.com/kfl/mosml/issues/49#issuecomment-368878055)
in an attachment to a GitHub comment.

Clone the repository and run `build.cmd` from its directory.

The test suite currently does not work on Windows.

## License

MIT.
