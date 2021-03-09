#!/bin/sh
set -e
BINUTILSVERSION=binutils-2.36.1
GDBVERSION=gdb-10.1
GDBOLDVERSION=gdb-8.3.1
AVARICEVERSION=AVaRICE-master
STLINKVERSION=stlink-1.6.1
OPENOCDRP2040VERSION=openocd-rp2040
OPENOCDPICODEBUGVERSION=openocd-picodebug
OPENOCDVERSION=openocd-0.11.0
BOSSAVERSION=BOSSA-1.9.1

HOSTISWINDOWS=
HOSTISLINUX=
HOSTISDARWIN=
HOSTISDARWINX86_64=
HOSTISDARWINARM64=
HOSTISLINUXX86_64=
HOSTISLINUXI686=

BUILDDIR=$(pwd)
if [ "$(uname -s)" = "Darwin" ]; then
  HOSTISDARWIN=TRUE
  PREFIXDIR=/usr/local/
  BREWDIR=$(dirname $(dirname $(which brew)))
  [ "$(uname -m)" = "x86_64" ] && HOSTISDARWINX86_64=TRUE
  [ "$(uname -m)" = "x86_64" ] && ARCHDIR=x86_64-darwin
  [ "$(uname -m)" = "arm64" ]  && HOSTISDARWINARM64=TRUE
  [ "$(uname -m)" = "arm64" ]  && ARCHDIR=aarch64-darwin
fi

if [ "$(uname -s)" = "Linux" -a "$CC" != "/usr/src/mxe/usr/bin/x86_64-w64-mingw32.static-gcc" ]; then
  HOSTISLINUX=TRUE
  PREFIXDIR=/usr/local/
  [ "$(uname -m)" = "x86_64" ] && HOSTISLINUXX86_64=TRUE
  [ "$(uname -m)" = "x86_64" ] && ARCHDIR=x86_64-linux
  [ "$(uname -m)" = "i686"   ] && HOSTISLINUXI686=TRUE
  [ "$(uname -m)" = "i686"   ] && ARCHDIR=i686-linux
  sudo apt-get install pv 2>/dev/null >/dev/null
fi

if [ "$(uname -s | sed 's,_NT.*$,_NT,g')" = "MINGW32_NT" ]; then
  HOSTISWINDOWS=TRUE
  PREFIXDIR=/mingw32
  ARCHDIR=x86_64-win64
fi

if [ "$(uname -s | sed 's,_NT.*$,_NT,g')" = "MINGW64_NT" ]; then
  HOSTISWINDOWS=TRUE
  PREFIXDIR=/mingw64
  ARCHDIR=x86_64-win64
fi

if [ "$CC" = "/usr/src/mxe/usr/bin/x86_64-w64-mingw32.static-gcc" ]; then
  HOSTISWINDOWS=TRUE
  PREFIXDIR=/usr/local/
  ARCHDIR=x86_64-win64
  sudo apt-get install pv 2>/dev/null >/dev/null
fi


OUTPUTDIR=$BUILDDIR/$ARCHDIR
[ ! -d $OUTPUTDIR ] && mkdir -p $OUTPUTDIR

PV=pv

. modules/gdbmultiarch.sh
. modules/gdboldmultiarch.sh
. modules/avarice.sh
. modules/stlink.sh
. modules/openocd.sh
. modules/openocdrp2040.sh
. modules/openocdpicodebug.sh
. modules/bossa.sh

cd $BUILDDIR

buildgdbmultiarch    all
buildgdboldmultiarch all
buildavarice
buildstlink
buildopenocd
buildopenocdrp2040
buildopenocdpicodebug
buildbossa

cd $ARCHDIR
rm -f ../devtools4fpc-$ARCHDIR.zip ||: 2>/dev/null
rm -rf ../AVaRICE-master/ ||:
rm -rf ../BOSSA-*/ ||:
rm -rf ../binutils-*/ ||:
rm -rf ../gdb-*/ ||:
rm -rf ../gdb-*/ ||:
rm -rf ../openocd-*/ ||:
rm -rf ../openocd-picodebug/ ||:
rm -rf ../openocd-rp2040/ ||:
rm -rf ../stlink-*/ ||:

zip -r -q ../devtools4fpc-$ARCHDIR.zip *
