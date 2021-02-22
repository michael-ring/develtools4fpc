#!/bin/sh
set -e
EXPATDIR=$HOME/devel/expat-2.2.9
BUILDDIR=$(pwd)
BINUTILSVERSION=binutils-2.36.1
GDBVERSION=gdb-10.1
AVARICEVERSION=AVaRICE-master
STLINKVERSION=stlink-1.6.1
OPENOCDRP2040VERSION=openocd-rp2040
OPENOCDVERSION=openocd-0.11.0-rc2
OUTPUTDIR=$BUILDDIR
HOSTISWINDOWS=
HOSTISLINUX=
HOSTISDARWIN=

[ "$(uname -s)" = "Darwin" ] && HOSTISDARWIN=TRUE

PV=pv

[ ! -d $BUILDDIR ] && mkdir -p $BUILDDIR

cd $BUILDDIR

buildbinutils() {
  TARGET=$1
  DESTSUBDIR=$2
  PROGRAMPREFIX=$3
  [ -z "$PROGRAMPREFIX" ] && PROGRAMPREFIX=${TARGET}
  INSTALLDIR=$OUTPUTDIR/cross/bin/$DESTSUBDIR/
  EXEEXT=
  [ -n "$HOSTISWINDOWS" ] && EXEEXT=.exe
  if [ -f $INSTALLDIR/${PROGRAMPREFIX}-ar${EXEEXT} ]; then
    echo "Skipping $BINUTILSVERSION for target $TARGET..."
    return 0
  else
    echo "Building $BINUTILSVERSION for target $TARGET..."
  fi
  (
    [ -d $BINUTILSVERSION ] && rm -rf $BINUTILSVERSION
    tar zxvf ${BINUTILSVERSION}.tar.gz 2>&1 | $PV --name="Unpack   " --line-mode --size 25100 >/dev/null
    cd $BINUTILSVERSION
    mkdir build
    cd build
    CONFIGUREFLAGS="--target=$TARGET --enable-static --disable-shared --disable-nls --program-prefix=${PROGRAMPREFIX}-"
    [ -n "$HOSTISDARWIN" -o -n "$HOSTISLINUX" ] && ../configure $CONFIGUREFLAGS 2>/dev/null | $PV --name="Configure" --line-mode --size 94 >/dev/null
    [ -n "$HOSTISWINDOWS" ]                     && ../configure $CONFIGUREFLAGS 2>/dev/null | $PV --name="Configure" --line-mode --size 94 >/dev/null
  
    [ -n "$HOSTISDARWIN" -o -n "$HOSTISLINUX" ] && make -j 8 2>/dev/null | $PV --name="Build    " --line-mode --size 3006 >/dev/null
    [ -n "$HOSTISWINDOWS" ]                     && make -j 8 2>/dev/null | $PV --name="Build    " --line-mode --size 3006 >/dev/null

    make install DESTDIR=$BUILDDIR 2>/dev/null | $PV --name="Install  " --line-mode --size 167 >/dev/null

    mkdir -p $INSTALLDIR
    for file in ar${EXEEXT} as${EXEEXT} ld${EXEEXT} objcopy${EXEEXT} ; do
      rm -f $INSTALLDIR/${PROGRAMPREFIX}-$file ||:  2>/dev/null
      cp $BUILDDIR/usr/local/bin/${PROGRAMPREFIX}-$file $INSTALLDIR
      strip $INSTALLDIR/${PROGRAMPREFIX}-$file
      [ -n "$HOSTISDARWIN" ] && codesign -f -o runtime --timestamp -s 'Developer ID Application: Michael Ring (4S7HMLQE4Z)' $INSTALLDIR/${PROGRAMPREFIX}-$file
    done
    rm -rf $BUILDDIR/usr
  )
}

buildgdb() {
  TARGET=$1
  DESTSUBDIR=$2
  PROGRAMPREFIX=$3
  [ -z "$PROGRAMPREFIX" ] && PROGRAMPREFIX=${TARGET}
  INSTALLDIR=$OUTPUTDIR/cross/bin/$DESTSUBDIR/
  EXEEXT=
  [ -n "$HOSTISWINDOWS" ] && EXEEXT=.exe

  if [ -f $INSTALLDIR/${PROGRAMPREFIX}-gdb${EXEEXT} ]; then
    echo "Skipping $GDBVERSION for target $TARGET..."
    return 0
  else
    echo "Building $GDBVERSION for target $TARGET..."
  fi
  (
    [ -d $GDBVERSION ] && rm -rf $GDBVERSION
    tar zxvf ${GDBVERSION}.tar.gz 2>&1 | $PV --name="Unpack   " --line-mode --size 13100 >/dev/null
    cd $GDBVERSION
    [ -n "$HOSTISDARWIN" ] && patch -p1 <../gdb-darwin.patch

    mkdir build
    cd build

    CONFIGUREFLAGS="--target=$TARGET --disable-shared --enable-static --disable-werror \
                    --enable-tui --with-expat --enable-curses \
                    --disable-xz --disable-xzdec --disable-lzmadec --disable-scripts \
                    --disable-doc --disable-docs --disable-nls \
                    --without-mpc --without-mpfr --without-gmp --without-cloog --without-isl \
                    --disable-sim --enable-gdbserver=no --without-python  --disable-gprof \
                    --without-guile --without-lzma \
                    --program-prefix=${PROGRAMPREFIX}-"
    [ -n "$HOSTISDARWIN" -o -n "$HOSTISLINUX" ] && ../configure $CONFIGUREFLAGS 2>/dev/null | $PV --name="Configure" --line-mode --size 96 >/dev/null
    [ -n "$HOSTISWINDOWS" ]                     && ../configure $CONFIGUREFLAGS 2>/dev/null | $PV --name="Configure" --line-mode --size 96 >/dev/null
  
    [ -n "$HOSTISDARWIN" -o -n "$HOSTISLINUX" ] && make -j 8 2>/dev/null | $PV --name="Build    " --line-mode --size 3740 >/dev/null
    [ -n "$HOSTISWINDOWS" ]                     && make -j 8 2>/dev/null | $PV --name="Build    " --line-mode --size 3740 >/dev/null

    #  cat gdb/Makefile | sed 's,$(TDEPLIBS) $(TUI_LIBRARY) $(CLIBS) $(LOADLIBES),$(TDEPLIBS) $(TUI_LIBRARY) $(CLIBS) $(LOADLIBES) -lssp,g' >Makefile.tmp
    #  mv Makefile.tmp gdb/Makefile
    #  make LDFLAGS=-static -j 8 2>/dev/null | $PV --name="ReBuild  " --line-mode --size 85 >/dev/null

    make install DESTDIR=$BUILDDIR 2>/dev/null | $PV --name="Install  " --line-mode --size 164 >/dev/null

    mkdir -p $INSTALLDIR
    for file in gdb${EXEEXT} ; do
      rm -f $INSTALLDIR/${PROGRAMPREFIX}-$file ||:  2>/dev/null
      cp $BUILDDIR/usr/local/bin/${PROGRAMPREFIX}-$file $INSTALLDIR
      strip $INSTALLDIR/${PROGRAMPREFIX}-$file
      [ -n "$HOSTISDARWIN" ] && codesign -f -o runtime --timestamp -s 'Developer ID Application: Michael Ring (4S7HMLQE4Z)' $INSTALLDIR/${PROGRAMPREFIX}-$file
    done
    rm -rf $BUILDDIR/usr
  )
}

buildavarice() {
  TARGET=$1
  DESTSUBDIR=$2
  PROGRAMPREFIX=$3
  [ -z "$PROGRAMPREFIX" ] && PROGRAMPREFIX=${TARGET}
  INSTALLDIR=$OUTPUTDIR/cross/bin/$DESTSUBDIR/
  EXEEXT=
  [ -n "$HOSTISWINDOWS" ] && EXEEXT=.exe

  if [ -f $INSTALLDIR/avarice${EXEEXT} ]; then
    echo "Skipping $AVARICEVERSION for target $TARGET..."
    return 0
  else
    echo "Building $AVARICEVERSION for target $TARGET..."
  fi
  (
    [ -d $AVARICEVERSION ] && rm -rf $AVARICEVERSION
    tar zxvf ${AVARICEVERSION}.tar.gz 2>&1 | $PV --name="Unpack   " --line-mode --size 13100 >/dev/null
    cd $AVARICEVERSION
    patch -p1 <../avarice-timeouts.patch
    cd avarice
    ./Bootstrap

    mkdir build
    cd build

    CONFIGUREFLAGS="--target=$TARGET --disable-shared --enable-static --disable-werror \
                    --enable-tui --with-expat --enable-curses \
                    --disable-xz --disable-xzdec --disable-lzmadec --disable-scripts \
                    --disable-doc --disable-docs --disable-nls \
                    --without-mpc --without-mpfr --without-gmp --without-cloog --without-isl \
                    --disable-sim --enable-gdbserver=no --without-python  --disable-gprof \
                    --without-guile --without-lzma"
    [ -n "$HOSTISDARWIN" -o -n "$HOSTISLINUX" ] && ../configure $CONFIGUREFLAGS 2>/dev/null | $PV --name="Configure" --line-mode --size 129 >/dev/null
    [ -n "$HOSTISWINDOWS" ]                     && ../configure $CONFIGUREFLAGS 2>/dev/null | $PV --name="Configure" --line-mode --size 129 >/dev/null
  
    [ -n "$HOSTISDARWIN" -o -n "$HOSTISLINUX" ] && make -j 8 2>/dev/null | $PV --name="Build    " --line-mode --size 64 >/dev/null
    [ -n "$HOSTISWINDOWS" ]                     && make -j 8 2>/dev/null | $PV --name="Build    " --line-mode --size 64 >/dev/null


    cd src
    [ -n "$HOSTISDARWIN" ] && g++  -g -O2 -D_THREAD_SAFE -pthread   -o avarice crc16.o devdescr.o ioreg.o jtag2bp.o jtag2io.o jtag2misc.o jtag2prog.o jtag2run.o jtag2rw.o jtag2usb.o jtag3bp.o jtag3io.o jtag3misc.o jtag3prog.o jtag3run.o jtag3rw.o jtagbp.o jtaggeneric.o jtagio.o jtagmisc.o jtagprog.o jtagrun.o jtagrw.o main.o remote.o utils.o gnu_getopt.o gnu_getopt1.o  /usr/local/opt/hidapi/lib/libhidapi.a /usr/local/opt/libusb/lib/libusb-1.0.a /usr/local/opt/libusb-compat/lib/libusb.a -lobjc -Wl,-framework,IOKit -Wl,-framework,CoreFoundation -Wl,-framework,AppKit /usr/local/opt/gettext/lib/libintl.a -liconv   -lz -ldl
    cd ..    

    make install DESTDIR=$BUILDDIR 2>/dev/null | $PV --name="Install  " --line-mode --size 15 >/dev/null

    mkdir -p $INSTALLDIR
    for file in avarice ; do
      rm -f $INSTALLDIR/$file ||:  2>/dev/null
      cp $BUILDDIR/usr/local/bin/$file $INSTALLDIR
      strip $INSTALLDIR/$file
      [ -n "$HOSTISDARWIN" ] && codesign -f -o runtime --timestamp -s 'Developer ID Application: Michael Ring (4S7HMLQE4Z)' $INSTALLDIR/$file
    done
    rm -rf $BUILDDIR/usr
  )
}

buildstlink() {
  TARGET=$1
  DESTSUBDIR=$2
  PROGRAMPREFIX=$3
  [ -z "$PROGRAMPREFIX" ] && PROGRAMPREFIX=${TARGET}
  INSTALLDIR=$OUTPUTDIR/cross/bin/$DESTSUBDIR/
  EXEEXT=
  [ -n "$HOSTISWINDOWS" ] && EXEEXT=.exe

  if [ -f $INSTALLDIR/st-util${EXEEXT} ]; then
    echo "Skipping $STLINKVERSION for target $TARGET..."
    return 0
  else
    echo "Building $STLINKVERSION for target $TARGET..."
  fi
  (
    [ -d $STLINKVERSION ] && rm -rf $STLINKVERSION
    tar zxvf ${STLINKVERSION}.tar.gz 2>&1 | $PV --name="Unpack   " --line-mode --size 230 >/dev/null
    cd $STLINKVERSION
  
    [ -n "$HOSTISDARWIN" -o -n "$HOSTISLINUX" ] && make release -j 8 2>/dev/null | $PV --name="Build    " --line-mode --size 113 >/dev/null
    [ -n "$HOSTISWINDOWS" ]                     && make release -j 8 2>/dev/null | $PV --name="Build    " --line-mode --size 113 >/dev/null

    mkdir -p $INSTALLDIR
    for file in st-util ; do
      rm -f $INSTALLDIR/$file ||:  2>/dev/null
      cp build/Release/bin/$file $INSTALLDIR
      strip $INSTALLDIR/$file
      [ -n "$HOSTISDARWIN" ] && codesign -f -o runtime --timestamp -s 'Developer ID Application: Michael Ring (4S7HMLQE4Z)' $INSTALLDIR/$file
    done
    rm -rf $BUILDDIR/usr
  )
}

buildopenocdrp2040() {
  TARGET=$1
  DESTSUBDIR=$2
  PROGRAMPREFIX=$3
  [ -z "$PROGRAMPREFIX" ] && PROGRAMPREFIX=${TARGET}
  INSTALLDIR=$OUTPUTDIR/cross/bin/$DESTSUBDIR/
  EXEEXT=
  [ -n "$HOSTISWINDOWS" ] && EXEEXT=.exe

  if [ -f $INSTALLDIR/openocd-rp2040${EXEEXT} ]; then
    echo "Skipping $OPENOCDRP2040VERSION for target $TARGET..."
    return 0
  else
    echo "Building $OPENOCDRP2040VERSION for target $TARGET..."
  fi
  (
    [ -d $OPENOCDRP2040VERSION ] && rm -rf $OPENOCDRP2040VERSION
    git clone https://github.com/raspberrypi/openocd.git --branch picoprobe --depth=1 openocd-rp2040
    cd $OPENOCDRP2040VERSION

    ./bootstrap 2>&1 | $PV --name="Bootstrap" --line-mode --size 44 >/dev/null

    mkdir build
    cd build

    CONFIGUREFLAGS="--enable-static --disable-shared --enable-picoprobe --disable-werror"
    [ -n "$HOSTISDARWIN" -o -n "$HOSTISLINUX" ] && ../configure $CONFIGUREFLAGS 2>/dev/null | $PV --name="Configure" --line-mode --size 438 >/dev/null
    [ -n "$HOSTISWINDOWS" ]                     && ../configure $CONFIGUREFLAGS 2>/dev/null | $PV --name="Configure" --line-mode --size 438 >/dev/null
  
    [ -n "$HOSTISDARWIN" -o -n "$HOSTISLINUX" ] && make -j 8 2>/dev/null | $PV --name="Build    " --line-mode --size 1250 >/dev/null
    [ -n "$HOSTISWINDOWS" ]                     && make -j 8 2>/dev/null | $PV --name="Build    " --line-mode --size 1250 >/dev/null

    [ -n "$HOSTISDARWIN" ] && gcc -Wall -Wstrict-prototypes -Wformat-security -Wshadow -Wextra -Wno-unused-parameter -Wbad-function-cast -Wcast-align -Wredundant-decls -g -O2 -o src/openocd src/main.o src/.libs/libopenocd.a -L/usr/local/Cellar/libusb/1.0.24/lib /usr/local/opt/libusb-compat/lib/libusb.a /usr/local/opt/libftdi/lib/libftdi1.a /usr/local/opt/hidapi/lib/libhidapi.a /usr/local/opt/libusb/lib/libusb-1.0.a -lobjc -Wl,-framework,IOKit -Wl,-framework,CoreFoundation -Wl,-framework,AppKit -lm ./jimtcl/libjim.a
    make install DESTDIR=$BUILDDIR 2>/dev/null | $PV --name="Install  " --line-mode --size 27 >/dev/null

    mkdir -p $INSTALLDIR
    for file in openocd ; do
      rm -f $INSTALLDIR/${file}-rp2040 ||:  2>/dev/null
      cp $BUILDDIR/usr/local/bin/$file $INSTALLDIR/${file}-rp2040
      strip $INSTALLDIR/${file}-rp2040
      [ -n "$HOSTISDARWIN" ] && codesign -f -o runtime --timestamp -s 'Developer ID Application: Michael Ring (4S7HMLQE4Z)' $INSTALLDIR/${file}-rp2040
    done
    rm -rf $BUILDDIR/usr
  )
}

buildopenocd() {
  TARGET=$1
  DESTSUBDIR=$2
  PROGRAMPREFIX=$3
  [ -z "$PROGRAMPREFIX" ] && PROGRAMPREFIX=${TARGET}
  INSTALLDIR=$OUTPUTDIR/cross/bin/$DESTSUBDIR/
  EXEEXT=
  [ -n "$HOSTISWINDOWS" ] && EXEEXT=.exe

  if [ -f $INSTALLDIR/openocd${EXEEXT} ]; then
    echo "Skipping $OPENOCDVERSION for target $TARGET..."
    return 0
  else
    echo "Building $OPENOCDVERSION for target $TARGET..."
  fi
  (
    [ -d $OPENOCDVERSION ] && rm -rf $OPENOCDVERSION
    git clone https://github.com/ntfreak/openocd.git openocd-0.11.0-rc2
    cd $OPENOCDVERSION

    ./bootstrap 2>&1 | $PV --name="Bootstrap" --line-mode --size 42 >/dev/null

    mkdir build
    cd build

    CONFIGUREFLAGS="--enable-static --disable-shared --disable-werror"
    [ -n "$HOSTISDARWIN" -o -n "$HOSTISLINUX" ] && ../configure $CONFIGUREFLAGS 2>/dev/null | $PV --name="Configure" --line-mode --size 439 >/dev/null
    [ -n "$HOSTISWINDOWS" ]                     && ../configure $CONFIGUREFLAGS 2>/dev/null | $PV --name="Configure" --line-mode --size 439 >/dev/null
  
    [ -n "$HOSTISDARWIN" -o -n "$HOSTISLINUX" ] && make -j 8 INFO_DEPS= 2>/dev/null | $PV --name="Build    " --line-mode --size 1250 >/dev/null
    [ -n "$HOSTISWINDOWS" ]                     && make -j 8 INFO_DEPS= 2>/dev/null | $PV --name="Build    " --line-mode --size 1250 >/dev/null

    [ -n "$HOSTISDARWIN" ] && gcc -Wall -Wstrict-prototypes -Wformat-security -Wshadow -Wextra -Wno-unused-parameter -Wbad-function-cast -Wcast-align -Wredundant-decls -Wpointer-arith -g -O2 -o src/openocd src/main.o src/.libs/libopenocd.a -L/usr/local/Cellar/libusb/1.0.24/lib /usr/local/opt/libusb-compat/lib/libusb.a /usr/local/opt/libftdi/lib/libftdi1.a /usr/local/opt/hidapi/lib/libhidapi.a /usr/local/opt/libusb/lib/libusb-1.0.a -lobjc -Wl,-framework,IOKit -Wl,-framework,CoreFoundation -Wl,-framework,AppKit -lm ./jimtcl/libjim.a
    make install INFO_DEPS= DESTDIR=$BUILDDIR 2>/dev/null | $PV --name="Install  " --line-mode --size 24 >/dev/null

    mkdir -p $INSTALLDIR
    for file in openocd ; do
      rm -f $INSTALLDIR/${file} ||:  2>/dev/null
      cp $BUILDDIR/usr/local/bin/$file $INSTALLDIR/${file}
      strip $INSTALLDIR/${file}
      [ -n "$HOSTISDARWIN" ] && codesign -f -o runtime --timestamp -s 'Developer ID Application: Michael Ring (4S7HMLQE4Z)' $INSTALLDIR/${file}
    done
    rm -rf $BUILDDIR/usr
  )
}


buildbinutils      arm-none-eabi    arm-embedded
buildbinutils      avr              avr-embedded
buildbinutils      mipsel-sde-elf   mipsel-embedded
buildbinutils      riscv32-none-elf riscv32-embedded
buildbinutils      riscv64-none-elf riscv64-embedded

buildgdb           arm-none-eabi    arm-embedded
buildgdb           avr              avr-embedded
buildgdb           mipsel-sde-elf   mipsel-embedded
buildgdb           riscv32-none-elf riscv32-embedded
buildgdb           riscv64-none-elf riscv64-embedded
buildavarice       avr              avr-embedded
buildstlink        arm-none-eabi    arm-embedded
buildopenocd       arm-none-eabi    arm-embedded
buildopenocdrp2040 arm-none-eabi    arm-embedded