This script will help you to build the binary or source DEB packages based on SPEC file.

Usage:
=====
```makeDeb [options] <spec-file>```

Options:
-------
  -h|--help             display this message
  -o|--outdirt=DIR      write result to DIR, home directory by default
  -V|--version          Print program version


SPEC file example
=================
```bash
# Name and version of the program
PROGRAM=flacon
VERSION=3.1.1

# Distributive name (Debian or Ubuntu)
DISTRIB=Ubuntu

# RElease number
RELEASENUM=1

# Realese name, separated by space
RELEASES="trusty xenial yakkety zesty artful"

# Repository on launchpad
PPA=flacon

# Build type (binary|source|debug)
TYPE=source

# Sign or no the source package and .changes file (yes|no)
SIGN=yes

```