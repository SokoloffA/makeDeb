This script will help you to build the binary or source DEB packages.

Usage: makeDeb.sh [options] <path-to-source-tar-file> <debian-directory>

Options:

   -h|--help             display this message
   -o|--outdirt=DIR      write result to DIR, home directory by default
   -r|--release=RELEASE  release name (sid, squeeze, testing, maveric, natty etc.), autodetect if ommited
   -d|--distrib=DISTRIB  distib type (Debian or Ubuntu), autodetect if ommited
   --ver=VERSION         package version
   -S|--sign             sign a result files
   -s|--source           build a source package, if omitted build a binary package
   --debug               debug mode, not build package - only create debian directory
   -V|--version          Print program version
