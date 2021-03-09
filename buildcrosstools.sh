#!/bin/sh
set -e
BINUTILSVERSION=binutils-2.36.1
HOSTISWINDOWS=
HOSTISLINUX=
HOSTISDARWIN=
HOSTISDARWINX86_64=
HOSTISDARWINARM64=

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
  ARCHDIR=i686-win64
fi

if [ "$(uname -s | sed 's,_NT.*$,_NT,g')" = "MINGW64_NT" ]; then
  HOSTISWINDOWS=TRUE
  PREFIXDIR=/mingw64
  ARCHDIR=x86_64-win64
fi

if [ "$CC" = "/usr/src/mxe/usr/bin/x86_64-w64-mingw32.static-gcc" ]; then
  HOSTISWINDOWS=TRUE
  HOSTISWINDOWSX86_64=TRUE
  PREFIXDIR=/usr/local/
  ARCHDIR=x86_64-win64
  sudo apt-get install pv 2>/dev/null >/dev/null
fi

if [ "$CC" = "/usr/src/mxe/usr/bin/i686-w64-mingw32.static-gcc" ]; then
  HOSTISWINDOWS=TRUE
  HOSTISWINDOWSI686=TRUE
  PREFIXDIR=/usr/local/
  ARCHDIR=i686-win64
  sudo apt-get install pv 2>/dev/null >/dev/null
fi

OUTPUTDIR=$BUILDDIR/$ARCHDIR
[ ! -d $OUTPUTDIR ] && mkdir -p $OUTPUTDIR

PV=pv

. modules/binutils.sh

cd $BUILDDIR

buildbinutils      arm-none-eabi    arm-embedded
buildbinutils      avr              avr-embedded
buildbinutils      mipsel-sde-elf   mipsel-embedded
buildbinutils      riscv32-none-elf riscv32-embedded
buildbinutils      riscv64-none-elf riscv64-embedded

echo "Cleanup..."

rm -rf $BINUTILSVERSION
