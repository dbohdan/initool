# initool

[![GitHub Actions CI status.](https://github.com/dbohdan/initool/actions/workflows/ci.yml/badge.svg)](https://github.com/dbohdan/initool/actions/workflows/ci.yml)&nbsp;
[![AppVeyor CI status.](https://ci.appveyor.com/api/projects/status/github/dbohdan/initool?branch=master&svg=true)](https://ci.appveyor.com/project/dbohdan/initool)

Initool lets you manipulate the contents of INI files from the command line.
Rather than modify an INI file in place, it prints the modified contents of the file to standard output.


## Contents

- [initool](#initool)
  - [Contents](#contents)
  - [Operation](#operation)
    - [Usage](#usage)
    - [Examples](#examples)
      - [POSIX](#posix)
      - [Windows](#windows)
      - [Both](#both)
    - [Whitespace](#whitespace)
    - [Nonexistent sections and properties](#nonexistent-sections-and-properties)
    - [Line endings](#line-endings)
    - [Case sensitivity](#case-sensitivity)
    - [Repeated items](#repeated-items)
    - [Text encodings](#text-encodings)
  - [Building and installation](#building-and-installation)
    - [FreeBSD, MacPorts port](#freebsd-macports-port)
    - [Building on FreeBSD, Linux, macOS](#building-on-freebsd-linux-macos)
    - [Building with Docker](#building-with-docker)
    - [Building on Windows](#building-on-windows)
  - [License](#license)


## Operation

### Usage

```none
initool [-i|--ignore-case] <command> [<arg> ...]
```

The following commands are available:

- `get <filename> [<section> [<key> [-v|--value-only]]]` — retrieve data.
- `exists <filename> <section> [<key>]` — check if a section or a property exists.
- `set <filename> <section> <key> <value>` — set a property's value.
- `delete <filename> <section> [<key>]` — delete a section or a property.
- `help` — print the help message.
- `version` — print the version number.

Commands can be abbreviated to their first letter: `g`, `e`, `s`, `d`, `h`, `v`.
The global option `-i` or `--ignore-case` must precede the command name.

When given a valid command, initool first reads the INI file `filename` in its entirety.
If the filename is `-`, initool reads standard input. For the commands `get`, `delete`, and `set`, it then prints to standard output the file's contents with the desired change.
For `exists`, it reports whether the section or the property exists through its exit status.

An INI file consists of properties (`key=value` lines) and sections (designated with a `[section name]` header line).
A property can be at the "top level" of the file (before any section headers) or in a section (after a section header).
To do something with a property, you must give initool the correct section name.
Section names and keys are [case-sensitive](#case-sensitivity) by default.
The global option `-i` or `--ignore-case` makes commands not distinguish between lower-case and upper-case [ASCII](https://en.wikipedia.org/wiki/ASCII) letters "A" through "Z" in section names and keys.

Top-level properties (properties not in any section) are accessed by using an empty string as the section name.
The `exists` command with just an empty string as the argument tells you whether or not there are any top-level properties.

The section name and key can be `*` (a "wildcard") to match anything.
For example, `set file.ini "*" foo bar` will set the key `foo` to the value `bar` in every existing section.
It will set the key `foo` at the top level if the file already has top-level properties.

The order in which properties appear in the INI file is preserved.
A new property is added after the last property in its section.

Initool preserves INI file comments (lines where the first character that is not [whitespace](#whitespace) is either `;` or `#`) in the output when it prints a whole file or a section.
It also preserves empty lines.

### Examples

#### POSIX

Let's replace the value of the top-level property `cache` in the file `settings.ini` from a
[POSIX-compatible shell](https://en.wikipedia.org/wiki/Unix_shell).
You can do this on FreeBSD, Linux, and macOS.

```sh
initool set settings.ini '' cache 1024 > settings.ini.new \
&& mv settings.ini.new settings.ini
```

You can pipeline invocations of initool to make multiple changes.
Enable `pipefail` in your shell
([compatibility information](https://unix.stackexchange.com/a/654932))
to handle errors correctly.

```sh
set -o pipefail
initool delete settings.ini test \
| initool set - '' cache 1024 > settings.ini.new \
&& mv settings.ini.new settings.ini
```

#### Windows

Now let's replace the value of the top-level property `cache` in the file `settings.ini` on Windows from the Command Prompt (`cmd.exe`):

```batch
initool set settings.ini "" cache 1024 > settings.ini.new
if %errorlevel% equ 0 move /y settings.ini.new settings.ini
```

You can use pipelines in the Windows Command Prompt.
Note that the Command Prompt has no feature like `pipefail`.
The `%errorlevel%` will be that of the last command in the pipeline, which in the example below cannot fail, so an `%errorlevel%` check would be pointless.
This is a reason to avoid pipelines in batch files.

```batch
initool delete settings.ini test | initool set - "" cache 1024 > settings.ini.new
move /y settings.ini.new settings.ini
```

#### Both

To retrieve only the value of a property rather than the whole property (the section, key, and value), use the flag `-v` or `--value-only`:

```sh
$ initool get tests/test.ini foo name1
[foo]
name1=foo1
$ initool get tests/test.ini foo name1 --value-only
foo1
```

### Whitespace

Initool defines whitespace as any mix of space and tab characters.
Leading and trailing whitespace around the section name, the key, and the value is removed from the output.

As a result, the following input files are all equivalent to each other for initool and produce the same output.
The output is identical to the first input.

```ini
[PHP]
short_open_tag=Off
```

```ini
[PHP]
short_open_tag = Off
```

```ini
    [PHP]
        short_open_tag   =     Off
```

Because of this, you can reformat initool-compatible INI files with the command `initool get file.ini`.

### Nonexistent sections and properties

How nonexistent sections and properties are handled depends on the command.

- `get`
  - **Result:** initool produces no output when the section or key does not exist.
  - **Exit status:** 0 if the file, section, or property exists, 1 if it doesn't.
- `exists`
  - **Result:** No output.
  - **Exit status:** 0 if the section or property exists, 1 if it doesn't.
- `set`
  - **Result:** The section and the property are created as needed.
  - **Exit status:** 0.
- `delete`
  - **Result:** Nothing is removed from the input in the output.
  - **Exit status:** 0 if the section or property was deleted, 1 if it wasn't.

### Line endings

When compiled according to the instructions below, initool will assume line endings to be LF on POSIX and either LF or CR+LF on Windows.
To operate on Windows files from POSIX, convert the files' line endings to LF and then back.
You can do this [with sed(1)](http://stackoverflow.com/a/2613834).

### Case sensitivity

Initool is [case-sensitive](https://en.wikipedia.org/wiki/Case_sensitivity) by default.
This means that it considers `[BOOT]` and `[boot]` different sections and `foo=5` and `FOO=5` properties with different keys.
The option `-i`/`--ignore-case` changes this behavior.
It makes initool treat ASCII letters "A" through "Z" and "a" through "z" as equal
when looking for sections and keys.
The case of section names and keys is preserved in the output regardless of the `-i`/`--ignore-case` option.

### Repeated items

If a file has multiple sections with identical names or identical keys in the same section, initool preserves them.
Commands act on all of them at the same time.

### Text encodings

Initool is encoding-naive and assumes one character is one byte.
It correctly processes UTF-8-encoded files when given UTF-8 command-line arguments but can't open files in UTF-16 or UTF-32.
On Windows, it will receive the command-line arguments in the encoding for your system's language for non-Unicode programs (e.g., [Windows-1252](https://en.wikipedia.org/wiki/Windows-1252)),
which limits what you can do with UTF-8-encoded files.


## Building and installation

### FreeBSD, MacPorts port

You can install `sysutils/initool` from the FreeBSD ports tree and MacPorts.

### Building on FreeBSD, Linux, macOS

Install [MLton](http://mlton.org/).
It is available as the package `mlton` in Fedora, FreeBSD, Homebrew, MacPorts, and
[other repositories](https://repology.org/project/mlton/versions).
On Debian 12 and Ubuntu 22.04, you will have to build MLton from source.

Clone the repository and run `make` then `sudo make install` in it.
Initool will be installed in `/usr/local/bin`.
Run `sudo make uninstall` to remove it.

### Building with Docker

You can build and run initool using Docker.

To build a Docker image for initool,
clone the repository,
`cd` to its directory,
then run the build command:

```sh
docker build -t initool:latest .
```

Wait for the build to finish.
Once it succeeds,
you can run initool from the Docker image you have built.

The following Docker command runs initool and gives it access to the current directory:

```sh
docker run --rm --user "$(id -u):$(id -g)" --volume "$PWD:/mnt/" --workdir /mnt/ initool:latest help
```

Pass in arguments to initool after `initool:latest`.
You may notice a delay when starting initool in a Docker container.

If you plan to use initool repeatedly,
you have the option to copy the binary to your Linux system.
This command copies the binary to the current directory:

```sh
docker run --entrypoint /bin/sh --rm --user "$(id -u):$(id -g)" --volume "$PWD:/mnt/" --workdir /mnt/ initool:latest -c 'cp /app/initool/initool /mnt/'
```

### Building on Windows

Prebuilt Windows (x86) binaries are attached to
[releases](https://github.com/dbohdan/initool/releases).

To build initool yourself, first install [MoSML](http://mosml.org).
The Windows installer is not available on the official site due to an antivirus false positive.
I have [mirrored the installer](https://github.com/kfl/mosml/issues/49#issuecomment-368878055) in an attachment to a GitHub comment.

Clone the repository and run `build.cmd` from its directory.

The test suite currently does not work on Windows.


## License

MIT.
