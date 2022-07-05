# PZZL File Format Specifications
version 1  
revision 0


A PZZL file is a simple wrapper around one arbitrary data blob.

## General structure:
1. 16 bytes header
2. optional metadata block
3. arbitrary data blob


## Filename extension:
- `.pzzl`
- `.pzl`

## Detailed Header Structure:

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


## Description

#### Magic:
The file signature for a PZZL file. Must match exactly.

#### Null byte:
Required, must be `00`.

#### Version Number:
Version `00` is only defined for compatibility and should not be used.  
In version `00`, the remaining 10 bytes of the header must be ignored entirely, and the data blob is assumed to immediately follow without any metadata chunk.  
Any version number greater than the current specification number is invalid.  
Any version number greater than the highest supported version by a reader program is to be considered invalid by the program.

#### Features:
Number `00` is only defined for compatibility and should not be used. In Version `01`, it can be interpreted as equivalent to being set to `01`, with metdata set to `00`, and padding is ignored.  
Number `01` is to be used if the binary blob has not been processed before being wrapped in the PZZL file.  
Number `02` is to be used if the binary blob was GPG signed externally before being wrapped in the PZZL file. Such signature and verification is beyond the scope of the PZZL File Format, and reader programs are not required to verify anything.

#### Metadata flag:
Indicates if the header is followed by a metadata chunk. Values other than `00` and `FF` are unsupported, but a reader program may choose to interpret any value greater than `00` as truthy.  
As of version `01`, the metadata block if present only contains a SHA-256 hash of the data blob. Verification of the hash is not required by programs reading PZZL files.

#### Padding:
Ignored. Programs can choose to implement additional feature in the give bytes.

---
---

This document is released under the [Creative Commons Zero v1.0 Universal (CC0-1.0)](https://creativecommons.org/publicdomain/zero/1.0/) license.
