# PZZL

### [Download `unpzzl` here](https://github.com/Heaxea/PZZL/releases/latest)

- [information about `unpzzl`](#unpzzl)
- [file format information](#pzzl-file-format)
- [PZZL File Format Specifications](PZZL%20File%20Format%20Specifications.md)

---

# `unpzzl`

`unpzzl` is a simple program to view the metadata in a PZZL file and extract the data.

```
unpzzl v1.1.0
  Supported PZZL version: 1
  Program version: 1.0

usage:
    unpzzl [-i][-s][-q] <FILE>...

options:
    -h, --help        show help and exit
    -v, --version     show version and exit
    -i, --info        info only:   do not extract data
    -s, --strict      strict mode: do not attempt to process invalid files
    -q, --quiet       quiet:  suppress output
    -z, --silent      silent: suppress most output
```

[Download `unpzzl` here](https://github.com/Heaxea/PZZL/releases/latest)

To compile, use the build script:
- Windows: `build.ps1`
- Linux: `build.sh`

Or directly:  
```shell
$ crystal build --stats --release --no-debug unpzzl.cr
```

Compiled with crystal release version `1.5.0` *(latest as of `2022/07/08`)*

`unpzzl` exit code details:

<details>
  <summary>click to view exit code information</summary>

| $?  |         code         | details |
| --: | -------------------- | ------- |
|  0  | SUCCESS              | no problem |
|  1  | UNKNOWN_ERROR        | generic error code |
|  2  | SYSTEM_ERROR         | file system error |
|  3  | INCORRECT_USAGE      | run `unpzzl -h` for usage information |
|  4  | MISSING_DATA         | couldn't find expected data |
|  5  | INVALID_FILE         | warnings are treated as error in strict mode |
|  6  | UNSUPPORTED_VERSION  | an update to `unpzzl` may be required |
|  7  | UNSUPPORTED_FEATURES | an update to `unpzzl` may be required |
|  8  | FILE_SKIPPED         | normal exit code if any file was not processed due to an error |

</details>

---

# PZZL File Format

A PZZL file is a simple wrapper around a data blob, with a `.pzzl` or `.pzl` filename extension.

[Full PZZL File Format Specifications](PZZL%20File%20Format%20Specifications.md)

current version: 1

### General structure:

1. 16 bytes header
2. optional metadata block
3. arbitrary data blob


### Detailed Header Structure:

<details open>
  <summary>click to toggle details visibility</summary>

1. Magic:
	- `50 5A 5A 4C` : ASCII 'PZZL'
2. Null byte:
	- `00` : always
3. Version Number:
	- `00` : reserved
	- `01` : normal
4. Features:
	- `00` : reserved
	- `01` : standard
	- `02` : GPG signed
5. Metadata flag:
	- `00` : no metadata
	- `FF` : standard
6. Padding:
	- `00 00 00 00 00 00 00 00` : if metadata flag is `00`
	- `FF FF FF FF FF FF FF FF` : if metadata flag is `FF`
</details>

---
