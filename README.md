# initool

Initool lets you manipulate the contents of INI files from the command line.
Rather than modify an INI file in place, it prints the modified contents of the file to standard output.


## Contents

- [Operation](#operation)
  - [Usage](#usage)
  - [Examples](#examples)
    - [POSIX](#posix)
    - [Windows](#windows)
    - [Both](#both)
      - [PowerShell](#powershell)
      - [Most shells](#most-shells)
  - [Whitespace](#whitespace)
  - [Nonexistent sections and properties](#nonexistent-sections-and-properties)
  - [Unparsable lines](#unparsable-lines)
  - [Line endings](#line-endings)
  - [Case sensitivity](#case-sensitivity)
  - [Repeated items](#repeated-items)
  - [Text encodings](#text-encodings)
- [Building and installation](#building-and-installation)
  - [Prebuilt binaries](#prebuilt-binaries)
  - [FreeBSD, MacPorts port](#freebsd-macports-port)
  - [Windows package](#windows-package)
  - [Building on FreeBSD, Linux, macOS](#building-on-freebsd-linux-macos)
  - [Building for Linux with Docker](#building-for-linux-with-docker)
  - [Building on Windows](#building-on-windows)
- [License](#license)


## Operation

### Usage

```none
initool [-i|--ignore-case] [-p|--pass-through] <command> [<arg> ...]
```

The following commands are available:

- `get <filename> [<section> [<key> [-v|--value-only]]]` — retrieve data.
- `exists <filename> <section> [<key>]` — check if a section or a property exists.
- `set <filename> <section> <key> <value>` — set a property's value.
- `replace <filename> <section> <key> <text> <replacement>` — replace the first occurrence of `<text>` with `<replacement>` in the property's value. Empty `<text>` matches empty values.
- `delete <filename> <section> [<key>]` — delete a section or a property.
- `help` — print the help message.
- `version` — print the version number.

Commands can be abbreviated to their first letter: `g`, `e`, `s`, `r`, `d`, `h`, `v`.
The global options `-i`/`--ignore-case` and `-p`/`--pass-through` must precede the command name.

When given a valid command, initool first reads the INI file `filename` in its entirety.
If the filename is `-`, initool reads standard input. For the commands `get`, `set`, `replace`, and `delete`, it then prints to standard output the file's contents with the desired change.
For `exists`, it reports whether the section or the property exists through its exit status.

**Initool never modifies the input file.**
One exception is if you redirect initool's output to the same file as input, which results in an empty file
[like with other programs](https://superuser.com/questions/597244/why-does-redirecting-the-output-of-a-file-to-itself-produce-a-blank-file).
Two wrapper scripts are included if you want to modify the input file:
[`initool-overwrite.sh`](initool-overwrite.sh) (POSIX shell)
and [`initool-overwrite.cmd`](initool-overwrite.cmd) (Windows batch).
The scripts redirect the output of initool to a temporary file, then overwrite the original.

An INI file consists of properties (`key=value` lines) and sections (designated with a `[section name]` header line).
A property can be at the "top level" of the file (before any section headers) or in a section (after a section header).
To do something with a property, you must give initool the correct section name.
Section names and keys are [case-sensitive](#case-sensitivity) by default, as is text for the command `replace`.
The global option `-i` or `--ignore-case` makes commands not distinguish between lower-case and upper-case [ASCII](https://en.wikipedia.org/wiki/ASCII) letters "A" through "Z" in section names, keys, and text.

Do not include the square brackets in the section argument.

```sh
# Right.
initool get tests/test.ini foo

# Wrong.
initool get tests/test.ini [foo]
```

Top-level properties (properties not in any section) are accessed by using an empty string as the section name.
The `exists` command with just an empty string as the argument tells you whether or not there are any top-level properties.

The section name and key can be `*` or `_` (a "wildcard") to match anything.
Only `_` works on Windows.
(Windows executables built with MoSML unavoidably expand `*` to a list of files.)
For example, `set file.ini _ foo bar` will set the key `foo` to the value `bar` in every existing section.
It will set the key `foo` at the top level if the file already has top-level properties.
To match a one-character section name or key that is `*` or `_`, use `\*` and `\_` respectively.
An initial backslash is removed from the section name and the key argument.

The order in which properties appear in the INI file is preserved.
A new property is added after the last property in its section.

Initool preserves INI file comments in the output when it prints a whole file or a section.
The comments are lines where the first character that is not [whitespace](#whitespace) is either `;` or `#`.
Initool also preserves empty lines.
Deleting a section removes it comments and empty lines.

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

You can use pipelines in the Windows Command Prompt,
although there is a reason to avoid them.
The Command Prompt has no feature like `pipefail`.
The `%errorlevel%` will be that of the last command in the pipeline, which in the example below cannot fail.
There is no `%errorlevel%` check in the example because it would be pointless.

```batch
initool delete settings.ini test | initool set - "" cache 1024 > settings.ini.new
move /y settings.ini.new settings.ini
```

#### Both

##### PowerShell

PowerShell lets you combine initool commands into pipelines
without the same problem as in `cmd.exe` (see above).
The variable `$?` will be `True` only if all commands in the pipeline succeed.

```powershell
# We assume `initool` is installed in `PATH`.
# Use `./initool` instead if the binary is in the current directory.
initool delete settings.ini test | initool set - '' cache 1024 > settings.ini.new
if ($?) { move -Force settings.ini.new settings.ini }
```

##### Most shells

These examples work in POSIX-compatible shells, fish, `cmd.exe`, PowerShell, and others.
`>` at the beginning of the line represents the shell's prompt.

###### Retrieving a value

To retrieve only the value of a property rather than the whole property (the section, key, and value), use the flag `-v` or `--value-only`:

```sh
> initool get tests/test.ini foo name1
[foo]
name1=foo1
> initool get tests/test.ini foo name1 --value-only
foo1
```

###### Replacing text in a value

The command `replace` can do two related things:

1. Replace the first occurrence of matching text in a property's value.
   The text can be any continuous part of the value, including the whole value.
2. Set a property's value only when it is empty.

Let's start with replacing part of a value.

```sh
> initool get tests/replace-part.ini
key=A longer value.
another-key=ABAABBAAABBB
empty=
> initool replace tests/replace-part.ini "" key value string > updated.ini
```

The contents of `updated.ini` will be:

```ini
key=A longer string.
another-key=ABAABBAAABBB
empty=
```

Now let's set the value of the key `empty`,
but only if it is actually empty.
Use an empty string as the `<text>` argument.

```sh
> initool replace tests/replace-part.ini "" empty "" no > updated.ini
```

The contents of `updated.ini` will be:

```ini
key=A longer value.
another-key=ABAABBAAABBB
empty=no
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
  - **Result:** Initool produces no output when the section or the key doesn't exist.
  - **Exit status:** 0 if the file, section, or property exists, 1 if it doesn't.
- `exists`
  - **Result:** No output.
  - **Exit status:** 0 if the section or property exists, 1 if it doesn't.
- `set`
  - **Result:** The section and the property are created as needed.
  - **Exit status:** 0.
- `replace`
  - **Result:** Nothing from the input changes in the output.
  - **Exit status:** 0 if the property exists and its value contains the text, 1 if it doesn't exist or the value doesn't contain the text.
- `delete`
  - **Result:** Nothing is removed from the input in the output.
  - **Exit status:** 0 if the section or property was deleted, 1 if it wasn't.

### Unparsable lines

When initool encounters a line it cannot parse,
it normally exits with an error.
This prevents problems caused by working on a malformed or non-INI file:
getting bogus data out of the file and corrupting the file by applying changes.
The global option `-p` or `--pass-through` disables the error and instead makes initool read and write lines verbatim when it fails to parse them.
Like comments, verbatim lines are treated as parts of their respective sections.

Use pass-through mode at your own risk.
You will not be alerted about syntax errors.
It may lead to surprising results.
For example, if a section header contains a typo like `[foo[`,
the properties in that section will be treated as belonging to the previous section.

### Line endings

When compiled according to the instructions below, initool will assume line endings to be LF on POSIX and either LF or CR+LF on Windows.
To operate on Windows files from POSIX, convert the files' line endings to LF and then back.
You can do this [with sed(1)](http://stackoverflow.com/a/2613834).

### Case sensitivity

Initool is [case-sensitive](https://en.wikipedia.org/wiki/Case_sensitivity) by default.
This means that it considers `[BOOT]` and `[boot]` different sections and `foo=5` and `FOO=5` properties with different keys.
The option `-i`/`--ignore-case` changes this behavior.
It makes initool treat ASCII letters "A" through "Z" and "a" through "z" as equal
when looking for sections and keys (every command) and text in values (`replace`).
The case of section names and keys is preserved in the output regardless of the `-i`/`--ignore-case` option.

### Repeated items

If a file has multiple sections with identical names or identical keys in the same section, initool preserves them.
Commands act on all of them at the same time.

### Text encodings

Initool is encoding-naive and assumes one character is one byte.
It correctly processes UTF-8-encoded files when given UTF-8 command-line arguments.
It exits with an encoding error if it detects the UTF-16 or UTF-32 [BOM](https://en.wikipedia.org/wiki/Byte_order_mark).
Trying to open a UTF-16 or UTF-32 file without the BOM results in an "invalid line" error because initool is unable to parse it.

On Windows, initool will receive the command-line arguments in the encoding for your system's language for non-Unicode programs (e.g., [Windows-1252](https://en.wikipedia.org/wiki/Windows-1252)),
which limits what you can do with UTF-8-encoded files.


## Building and installation

### Prebuilt binaries

Prebuilt binaries for Linux (x86-64), macOS (ARM64 and x86-64), and Windows (x86)
are attached to
[releases](https://github.com/dbohdan/initool/releases).
CI also builds a set of test binaries for every Git push.

Linux and macOS binary distributions include a copy of the
[GNU Multiple Precision Arithmetic Library](https://en.wikipedia.org/wiki/GNU_Multiple_Precision_Arithmetic_Library)
used under the GNU LGPL version 3.

BSD, Linux, and macOS binaries are not marked as executable because of a
[limitation of `@actions/upload-artifact`](https://github.com/actions/upload-artifact/issues/38).
Extract the archive and run the command

```sh
chmod +x initool
```

On macOS, you may need to run the following command once you have extracted the archive:

```sh
xattr -d com.apple.quarantine initool
```

### FreeBSD, MacPorts port

You can install `sysutils/initool` from the FreeBSD ports tree and MacPorts.

### Windows package

Initool can be installed with Chocolatey:

```batch
choco install initool
```

### Building on FreeBSD, Linux, macOS

Install [MLton](http://mlton.org/).
It is available as the package `mlton` in Fedora, FreeBSD, Homebrew, MacPorts, Ubuntu 24.04, and
[other repositories](https://repology.org/project/mlton/versions).
On Debian 12 and Ubuntu 22.04, you will have to build MLton from source.

Clone the repository and run `make` then `sudo make install` in it.
Initool will be installed in `/usr/local/bin`.
Run `sudo make uninstall` to remove it.

### Building for Linux with Docker

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

To build initool yourself, first install [MoSML](http://mosml.org).
The Windows installer is not available on the official site due to an antivirus false positive.
I have [mirrored the installer](https://github.com/kfl/mosml/issues/49#issuecomment-368878055) in an attachment to a GitHub comment.

Clone the repository and run `build.cmd` from its directory.

To test on Windows, download [busybox-w32](https://frippery.org/busybox/) as `busybox.exe` to the repository directory, then run `test.cmd`.

## License

MIT.
