#!/bin/sh
set -e
BUILDDIR=$(pwd)
BINUTILSVERSION=binutils-2.36.1
GDBVERSION=gdb-10.1
AVARICEVERSION=AVaRICE-master
STLINKVERSION=stlink-1.6.1
OPENOCDRP2040VERSION=openocd-rp2040
OPENOCDVERSION=openocd-0.11.0-rc2
BOSSAVERSION=BOSSA-1.9.1
OUTPUTDIR=$BUILDDIR
HOSTISWINDOWS=
HOSTISLINUX=
HOSTISDARWIN=
HOSTISDARWINX86_64=
HOSTISDARWINARM64=

if [ "$(uname -s)" = "Darwin" ]; then
  HOSTISDARWIN=TRUE
  PREFIXDIR=/usr/local/
  BREWDIR=$(dirname $(dirname $(which brew)))
  [ "$(uname -m)" = "x86_64" ] && HOSTISDARWINX86_64=TRUE
  [ "$(uname -m)" = "x86_64" ] && ARCHDIR=x86_64-darwin
  [ "$(uname -m)" = "arm64" ]  && HOSTISDARWINARM64=TRUE
  [ "$(uname -m)" = "arm64" ]  && ARCHDIR=aarch64-darwin
fi
if [ "$(uname -s)" = "Linux" ]; then
  HOSTISLINUX=TRUE
  PREFIXDIR=/usr/local/
  [ "$(uname -m)" = "x86_64" ] && HOSTISLINUXX86_64=TRUE
  [ "$(uname -m)" = "x86_64" ] && ARCHDIR=x86_64-linux
fi

if [ "$(uname -s | sed 's,_NT.*$,_NT,g')" = "MINGW64_NT" ]; then
  HOSTISWINDOWS=TRUE
  PREFIXDIR=/mingw64
fi

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
      cp $BUILDDIR/$PREFIXDIR/bin/${PROGRAMPREFIX}-$file $INSTALLDIR
      strip $INSTALLDIR/${PROGRAMPREFIX}-$file
      [ -n "$HOSTISDARWIN" ] && codesign -f -o runtime --timestamp -s 'Developer ID Application: Michael Ring (4S7HMLQE4Z)' $INSTALLDIR/${PROGRAMPREFIX}-$file
    done
    rm -rf $BUILDDIR/$PREFIXDIR
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
    [ -n "$HOSTISDARWIN" ] && patch -p1 <../patches/gdb-darwin.patch
    if [ -n "$HOSTISWINDOWS" ]; then
      patch -p1 <../patches/gdb-perfomance.patch
      patch -p1 <../patches/gdb-fix-using-gnu-print.patch
      patch -p1 <../patches/gdb-7.12-dynamic-libs.patch
      patch -p1 <../patches/python-configure-path-fixes.patch
      patch -p1 <../patches/gdb-fix-tui-with-pdcurses.patch
      patch -p1 <../patches/gdb-lib-order.patch
      patch -p1 <../patches/gdb-fix-array.patch
      patch -p1 <../patches/gdb-home-is-userprofile.patch
      sed -i "/ac_cpp=/s/\$CPPFLAGS/\$CPPFLAGS -O2/" libiberty/configure
      CPPFLAGS+=" -I${MINGW_PREFIX}/include/ncurses"
      CFLAGS+=" -I${MINGW_PREFIX}/include/ncurses"
      CXXFLAGS+=" -I${MINGW_PREFIX}/include/ncurses"
      LDFLAGS+=" -fstack-protector"
    fi

    mkdir build
    cd build

    CONFIGUREFLAGS="--target=$TARGET --disable-shared --enable-static --disable-werror --without-curses \
                    --disable-tui --with-expat --without-babeltrace --disable-unit-tests --disable-source-highlight \
                    --disable-xz --disable-xzdec --disable-lzmadec --disable-scripts \
                    --disable-doc --disable-docs --disable-nls --disable-rpath --disable-libmcheck --without-libunwind \
                    --without-mpc --without-mpfr --without-gmp --without-cloog --without-isl \
                    --disable-sim --enable-gdbserver=no --without-python  --disable-gprof --without-debuginfod \
                    --without-guile --without-lzma --without-xxhash --without-intel-pt --disable-inprocess-agent \
                    --program-prefix=${PROGRAMPREFIX}-"
    [ -n "$HOSTISDARWIN" -o -n "$HOSTISLINUX" ] && CFLAGS="-DNDEBUG -static-libstdc++ -static-libgcc" CXXFLAGS="-DNDEBUG -static-libstdc++ -static-libgcc" ../configure $CONFIGUREFLAGS 2>/dev/null | $PV --name="Configure" --line-mode --size 96 >/dev/null
    [ -n "$HOSTISWINDOWS" ]                     && CFLAGS=-DNDEBUG CXXFLAGS=-DNDEBUG ../configure $CONFIGUREFLAGS --with-system-readline 2>/dev/null | $PV --name="Configure" --line-mode --size 96 >/dev/null
  
    [ -n "$HOSTISDARWIN" -o -n "$HOSTISLINUX" ] && make -j 8 2>/dev/null | $PV --name="Build    " --line-mode --size 3740 >/dev/null
    [ -n "$HOSTISWINDOWS" ]                     && make -j 8 2>/dev/null | $PV --name="Build    " --line-mode --size 3740 >/dev/null

    if [ -n "$HOSTISLINUX" ]; then
      cd gdb
      rm -f gdb
      sed --in-place "s,-ltermcap,/usr/lib/x86_64-linux-gnu/libtermcap.a,g" Makefile
      sed --in-place "s,-lexpat,/usr/lib/x86_64-linux-gnu/libexpat.a,g" Makefile
      make
    fi
    #  cat gdb/Makefile | sed 's,$(TDEPLIBS) $(TUI_LIBRARY) $(CLIBS) $(LOADLIBES),$(TDEPLIBS) $(TUI_LIBRARY) $(CLIBS) $(LOADLIBES) -lssp,g' >Makefile.tmp
    #  mv Makefile.tmp gdb/Makefile
    #  make LDFLAGS=-static -j 8 2>/dev/null | $PV --name="ReBuild  " --line-mode --size 85 >/dev/null

    make install DESTDIR=$BUILDDIR 2>/dev/null | $PV --name="Install  " --line-mode --size 164 >/dev/null

    mkdir -p $INSTALLDIR
    for file in gdb${EXEEXT} ; do
      rm -f $INSTALLDIR/${PROGRAMPREFIX}-$file ||:  2>/dev/null
      cp $BUILDDIR/$PREFIXDIR/bin/${PROGRAMPREFIX}-$file $INSTALLDIR
      strip $INSTALLDIR/${PROGRAMPREFIX}-$file
      [ -n "$HOSTISDARWIN" ] && codesign -f -o runtime --timestamp -s 'Developer ID Application: Michael Ring (4S7HMLQE4Z)' $INSTALLDIR/${PROGRAMPREFIX}-$file
    done
    rm -rf $BUILDDIR/PREFIXDIR
  )
}

buildavarice() {
  TARGET=$1
  DESTSUBDIR=$2
  PROGRAMPREFIX=$3
  [ -z "$PROGRAMPREFIX" ] && PROGRAMPREFIX=${TARGET}
  INSTALLDIR=$OUTPUTDIR/bin/$ARCHDIR/
  EXEEXT=
  [ -n "$HOSTISWINDOWS" ] && EXEEXT=.exe

  if [ -n "$HOSTISWINDOWS" ]; then
    echo "Skipping $AVARICEVERSION for target $TARGET, not supported..."
    return
  fi

  if [ -f $INSTALLDIR/avarice${EXEEXT} ]; then
    echo "Skipping $AVARICEVERSION for target $TARGET..."
    return 0
  else
    echo "Building $AVARICEVERSION for target $TARGET..."
  fi
  (
    [ -d $AVARICEVERSION ] && rm -rf $AVARICEVERSION
    tar zxvf ${AVARICEVERSION}.tar.gz 2>&1 | $PV --name="Unpack   " --line-mode --size 81 >/dev/null
    cd $AVARICEVERSION
    patch -p1 <../patches/avarice-timeouts.patch >/dev/null
    cd avarice
    ./Bootstrap 2>&1 | $PV --name="Bootstrap" --line-mode --size 13 >/dev/null

    mkdir build
    cd build

    CONFIGUREFLAGS="--target=$TARGET --disable-shared --enable-static --disable-werror"
    [ -n "$HOSTISDARWIN" -o -n "$HOSTISLINUX" ] && CFLAGS="-DNDEBUG -static-libstdc++ -static-libgcc" CXXFLAGS="-DNDEBUG -static-libstdc++ -static-libgcc" ../configure $CONFIGUREFLAGS 2>/dev/null | $PV --name="Configure" --line-mode --size 129 >/dev/null
    [ -n "$HOSTISWINDOWS" ]                     && ../configure $CONFIGUREFLAGS 2>/dev/null | $PV --name="Configure" --line-mode --size 129 >/dev/null
  
    [ -n "$HOSTISDARWIN" -o -n "$HOSTISLINUX" ] && make -j 8 2>/dev/null | $PV --name="Build    " --line-mode --size 74 >/dev/null
    [ -n "$HOSTISWINDOWS" ]                     && make -j 8 2>/dev/null | $PV --name="Build    " --line-mode --size 64 >/dev/null


    cd src
    [ -n "$HOSTISDARWINX86_64" ] && g++  -g -O2 -D_THREAD_SAFE -pthread   -o avarice crc16.o devdescr.o ioreg.o jtag2bp.o jtag2io.o jtag2misc.o jtag2prog.o jtag2run.o jtag2rw.o jtag2usb.o jtag3bp.o jtag3io.o jtag3misc.o jtag3prog.o jtag3run.o jtag3rw.o jtagbp.o jtaggeneric.o jtagio.o jtagmisc.o jtagprog.o jtagrun.o jtagrw.o main.o remote.o utils.o gnu_getopt.o gnu_getopt1.o  /usr/local/opt/hidapi/lib/libhidapi.a /usr/local/opt/libusb/lib/libusb-1.0.a /usr/local/opt/libusb-compat/lib/libusb.a -lobjc -Wl,-framework,IOKit -Wl,-framework,CoreFoundation -Wl,-framework,AppKit /usr/local/opt/gettext/lib/libintl.a -liconv   -lz -ldl
    [ -n "$HOSTISDARWINARM64" ] && g++  -g -O2 -D_THREAD_SAFE -pthread   -o avarice crc16.o devdescr.o ioreg.o jtag2bp.o jtag2io.o jtag2misc.o jtag2prog.o jtag2run.o jtag2rw.o jtag2usb.o jtag3bp.o jtag3io.o jtag3misc.o jtag3prog.o jtag3run.o jtag3rw.o jtagbp.o jtaggeneric.o jtagio.o jtagmisc.o jtagprog.o jtagrun.o jtagrw.o main.o remote.o utils.o gnu_getopt.o gnu_getopt1.o /opt/homebrew/lib/libhidapi.a /opt/homebrew/lib/libusb-1.0.a /opt/homebrew/lib/libusb.a -lobjc -Wl,-framework,IOKit -Wl,-framework,CoreFoundation -Wl,-framework,AppKit /opt/homebrew/lib/libintl.a -liconv   -lz -ldl
    cd ..    

    make install DESTDIR=$BUILDDIR 2>/dev/null | $PV --name="Install  " --line-mode --size 31 >/dev/null

    mkdir -p $INSTALLDIR
    for file in avarice ; do
      rm -f $INSTALLDIR/$file ||:  2>/dev/null
      cp $BUILDDIR/$PREFIXDIR/bin/$file $INSTALLDIR
      strip $INSTALLDIR/$file
      [ -n "$HOSTISDARWIN" ] && codesign -f -o runtime --timestamp -s 'Developer ID Application: Michael Ring (4S7HMLQE4Z)' $INSTALLDIR/$file
    done
    rm -rf $BUILDDIR/$PREFIXDIR
  )
}

buildstlink() {
  TARGET=$1
  DESTSUBDIR=$2
  PROGRAMPREFIX=$3
  [ -z "$PROGRAMPREFIX" ] && PROGRAMPREFIX=${TARGET}
  INSTALLDIR=$OUTPUTDIR/bin/$ARCHDIR/
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
  
    [ -n "$HOSTISDARWIN" ] && make release -j 8 2>/dev/null | $PV --name="Build    " --line-mode --size 113 >/dev/null
    if [ -n "$HOSTISLINUX" ]; then
      mkdir build
      cd build
      cmake .. 2>/dev/null | $PV --name="Cmake    " --line-mode --size 64 >/dev/null
      make stlink-static | $PV --name="Build    " --line-mode --size 10 >/dev/null
      make -j 8 2>/dev/null | $PV --name="Build    " --line-mode --size 39 >/dev/null
      /usr/bin/cc -std=gnu11 -Wall -Wextra -Wshadow -D_FORTIFY_SOURCE=2 -fstrict-aliasing -Wundef -Wformat -Wformat-security \
                  -Wmaybe-uninitialized -Wimplicit-function-declaration -Wredundant-decls -fPIC -O2 -Werror \
                  CMakeFiles/st-info.dir/src/tools/info.c.o \
                  -o bin/st-info lib/libstlink.a /usr/lib/x86_64-linux-gnu/libusb-1.0.a -pthread -ludev
      /usr/bin/cc -std=gnu11 -Wall -Wextra -Wshadow -D_FORTIFY_SOURCE=2 -fstrict-aliasing -Wundef -Wformat -Wformat-security \
                  -Wmaybe-uninitialized -Wimplicit-function-declaration -Wredundant-decls -fPIC -O2 -Werror \
                  CMakeFiles/st-util.dir/src/st-util/gdb-remote.c.o CMakeFiles/st-util.dir/src/st-util/gdb-server.c.o \
                  CMakeFiles/st-util.dir/src/st-util/semihosting.c.o \
                  -o bin/st-util lib/libstlink.a /usr/lib/x86_64-linux-gnu/libusb-1.0.a -pthread -ludev
      /usr/bin/cc -std=gnu11 -Wall -Wextra -Wshadow -D_FORTIFY_SOURCE=2 -fstrict-aliasing -Wundef -Wformat -Wformat-security \
                  -Wmaybe-uninitialized -Wimplicit-function-declaration -Wredundant-decls -fPIC -O2 -Werror \
                  CMakeFiles/st-flash.dir/src/tools/flash.c.o CMakeFiles/st-flash.dir/src/tools/flash_opts.c.o \
                  -o bin/st-flash  lib/libstlink.a /usr/lib/x86_64-linux-gnu/libusb-1.0.a -pthread -ludev
      cd ..
    fi

    if [ -n "$HOSTISWINDOWS" ]; then
      mkdir build
      cd build
      /mingw64/bin/cmake.exe -G "MinGW Makefiles" ..
      /mingw64/bin/mingw32-make.exe
      make release -j 8 2>/dev/null | $PV --name="Build    " --line-mode --size 113 >/dev/null
      cd ..
    fi
    mkdir -p $INSTALLDIR
    for file in st-flash st-info st-util ; do
      rm -f $INSTALLDIR/$file ||:  2>/dev/null
      cp build/bin/$file $INSTALLDIR
      strip $INSTALLDIR/$file
      [ -n "$HOSTISDARWIN" ] && codesign -f -o runtime --timestamp -s 'Developer ID Application: Michael Ring (4S7HMLQE4Z)' $INSTALLDIR/$file ||:
    done
  )
}

buildopenocdrp2040() {
  TARGET=$1
  DESTSUBDIR=$2
  PROGRAMPREFIX=$3
  [ -z "$PROGRAMPREFIX" ] && PROGRAMPREFIX=${TARGET}
  INSTALLDIR=$OUTPUTDIR/bin/$ARCHDIR/
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
    git clone https://github.com/raspberrypi/openocd.git --branch picoprobe --depth=1 openocd-rp2040 2>&1 | $PV --name="Cloning  " --line-mode --size 438 >/dev/null
    cd $OPENOCDRP2040VERSION

    patch -p1 <../patches/openocd-rp2040-fpcupspecialpath.patch

    ./bootstrap 2>&1 | $PV --name="Bootstrap" --line-mode --size 44 >/dev/null

    mkdir build
    cd build

    CONFIGUREFLAGS="--enable-static --disable-shared --enable-picoprobe --disable-werror"
    [ -n "$HOSTISDARWIN" -o -n "$HOSTISLINUX" ] && ../configure $CONFIGUREFLAGS 2>/dev/null | $PV --name="Configure" --line-mode --size 438 >/dev/null
    [ -n "$HOSTISWINDOWS" ]                     && ../configure $CONFIGUREFLAGS 2>/dev/null | $PV --name="Configure" --line-mode --size 438 >/dev/null
  
    [ -n "$HOSTISDARWIN" -o -n "$HOSTISLINUX" ] && make -j 8 2>/dev/null | $PV --name="Build    " --line-mode --size 1250 >/dev/null
    [ -n "$HOSTISWINDOWS" ]                     && make -j 8 2>/dev/null | $PV --name="Build    " --line-mode --size 1250 >/dev/null

    [ -n "$HOSTISDARWINX86_64" ]  && gcc -Wall -Wstrict-prototypes -Wformat-security -Wshadow -Wextra -Wno-unused-parameter -Wbad-function-cast -Wcast-align -Wredundant-decls -g -O2 -o src/openocd src/main.o src/.libs/libopenocd.a /usr/local/opt/libusb-compat/lib/libusb.a /usr/local/opt/libftdi/lib/libftdi1.a /usr/local/opt/hidapi/lib/libhidapi.a /usr/local/opt/libusb/lib/libusb-1.0.a -lobjc -Wl,-framework,IOKit -Wl,-framework,CoreFoundation -Wl,-framework,AppKit -lm ./jimtcl/libjim.a
    [ -n "$HOSTISDARWINARM64" ] && gcc -Wall -Wstrict-prototypes -Wformat-security -Wshadow -Wextra -Wno-unused-parameter -Wbad-function-cast -Wcast-align -Wredundant-decls -g -O2 -o src/openocd src/main.o src/.libs/libopenocd.a                /opt/homebrew/lib/libusb.a          /opt/homebrew/lib/libftdi1.a         /opt/homebrew/lib/libhidapi.a         /opt/homebrew/lib/libusb-1.0.a -lobjc -Wl,-framework,IOKit -Wl,-framework,CoreFoundation -Wl,-framework,AppKit -lm ./jimtcl/libjim.a
    make install DESTDIR=$BUILDDIR 2>/dev/null | $PV --name="Install  " --line-mode --size 44 >/dev/null

    mkdir -p $INSTALLDIR
    for file in openocd ; do
      rm -f $INSTALLDIR/${file}-rp2040 ||:  2>/dev/null
      cp $BUILDDIR/$PREFIXDIR/bin/$file $INSTALLDIR/${file}-rp2040
      strip $INSTALLDIR/${file}-rp2040
      [ -n "$HOSTISDARWIN" ] && codesign -f -o runtime --timestamp -s 'Developer ID Application: Michael Ring (4S7HMLQE4Z)' $INSTALLDIR/${file}-rp2040
    done
    mkdir -p $INSTALLDIR/../../share/openocd/scripts/{board,interface,target}
    cp $BUILDDIR/$PREFIXDIR/share/openocd/scripts/interface/picoprobe.cfg $INSTALLDIR/../../share/openocd/scripts/interface/
    cp $BUILDDIR/$PREFIXDIR/share/openocd/scripts/target/rp2040*.cfg $INSTALLDIR/../../share/openocd/scripts/target/
    cp $BUILDDIR/$PREFIXDIR/share/openocd/scripts/target/swj-dp*.tcl $INSTALLDIR/../../share/openocd/scripts/target/
    cat >$INSTALLDIR/../../share/openocd/scripts/board/pico.cfg <<EOF
source [find interface/picoprobe.cfg]
source [find target/RP2040.cfg]    
EOF
    rm -rf $BUILDDIR/$PREFIXDIR
  )
}

buildopenocd() {
  TARGET=$1
  DESTSUBDIR=$2
  PROGRAMPREFIX=$3
  [ -z "$PROGRAMPREFIX" ] && PROGRAMPREFIX=${TARGET}
  INSTALLDIR=$OUTPUTDIR/bin/$ARCHDIR/
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
    git clone https://github.com/ntfreak/openocd.git openocd-0.11.0-rc2 2>&1 | $PV --name="Cloning  " --line-mode --size 438 >/dev/null
    cd $OPENOCDVERSION

    patch -p1 <../patches/openocd-fpcupspecialpath.patch
    
    ./bootstrap 2>&1 | $PV --name="Bootstrap" --line-mode --size 42 >/dev/null

    mkdir build
    cd build

    CONFIGUREFLAGS="--enable-static --disable-shared --disable-werror"
    [ -n "$HOSTISDARWIN" -o -n "$HOSTISLINUX" ] && ../configure $CONFIGUREFLAGS 2>/dev/null | $PV --name="Configure" --line-mode --size 439 >/dev/null
    [ -n "$HOSTISWINDOWS" ]                     && ../configure $CONFIGUREFLAGS 2>/dev/null | $PV --name="Configure" --line-mode --size 439 >/dev/null
  
    [ -n "$HOSTISDARWIN" -o -n "$HOSTISLINUX" ] && make -j 8 INFO_DEPS= 2>/dev/null | $PV --name="Build    " --line-mode --size 1250 >/dev/null
    [ -n "$HOSTISWINDOWS" ]                     && make -j 8 INFO_DEPS= 2>/dev/null | $PV --name="Build    " --line-mode --size 1250 >/dev/null

    [ -n "$HOSTISDARWINX86_64" ]  && gcc -Wall -Wstrict-prototypes -Wformat-security -Wshadow -Wextra -Wno-unused-parameter -Wbad-function-cast -Wcast-align -Wredundant-decls -Wpointer-arith -g -O2 -o src/openocd src/main.o src/.libs/libopenocd.a /usr/local/opt/libusb-compat/lib/libusb.a /usr/local/opt/libftdi/lib/libftdi1.a /usr/local/opt/hidapi/lib/libhidapi.a /usr/local/opt/libusb/lib/libusb-1.0.a -lobjc -Wl,-framework,IOKit -Wl,-framework,CoreFoundation -Wl,-framework,AppKit -lm ./jimtcl/libjim.a
    [ -n "$HOSTISDARWINARM64" ] && gcc -Wall -Wstrict-prototypes -Wformat-security -Wshadow -Wextra -Wno-unused-parameter -Wbad-function-cast -Wcast-align -Wredundant-decls -Wpointer-arith -g -O2 -o src/openocd src/main.o src/.libs/libopenocd.a                /opt/homebrew/lib/libusb.a          /opt/homebrew/lib/libftdi1.a         /opt/homebrew/lib/libhidapi.a         /opt/homebrew/lib/libusb-1.0.a -lobjc -Wl,-framework,IOKit -Wl,-framework,CoreFoundation -Wl,-framework,AppKit -lm ./jimtcl/libjim.a
    make install INFO_DEPS= DESTDIR=$BUILDDIR 2>/dev/null | $PV --name="Install  " --line-mode --size 44 >/dev/null

    mkdir -p $INSTALLDIR
    for file in openocd ; do
      rm -f $INSTALLDIR/${file} ||:  2>/dev/null
      cp $BUILDDIR/$PREFIXDIR/bin/$file $INSTALLDIR/${file}
      strip $INSTALLDIR/${file}
      [ -n "$HOSTISDARWIN" ] && codesign -f -o runtime --timestamp -s 'Developer ID Application: Michael Ring (4S7HMLQE4Z)' $INSTALLDIR/${file}
    done
    mkdir -p $INSTALLDIR/../../share/openocd
    cp -r $BUILDDIR/$PREFIXDIR/share/openocd $INSTALLDIR/../../share/
    rm -rf $BUILDDIR/$PREFIXDIR
  )
}

buildbossa() {
  TARGET=$1
  DESTSUBDIR=$2
  PROGRAMPREFIX=$3
  [ -z "$PROGRAMPREFIX" ] && PROGRAMPREFIX=${TARGET}
  INSTALLDIR=$OUTPUTDIR/bin/$ARCHDIR/
  EXEEXT=
  [ -n "$HOSTISWINDOWS" ] && EXEEXT=.exe

  if [ -f $INSTALLDIR/bossac${EXEEXT} ]; then
    echo "Skipping $BOSSAVERSION for target $TARGET..."
    return 0
  else
    echo "Building $BOSSAVERSION for target $TARGET..."
  fi
  (
    [ -d $BOSSAVERSION ] && rm -rf $BOSSAVERSION
    tar zxvf ${BOSSAVERSION}.tar.gz 2>&1 | $PV --name="Unpack   " --line-mode --size 99 >/dev/null
    cd $BOSSAVERSION
    CFLAGS="-DNDEBUG -static-libstdc++ -static-libgcc" CXXFLAGS="-DNDEBUG -static-libstdc++ -static-libgcc" make bin/bossac  | $PV --name="Building " --line-mode --size 30 >/dev/null 2>/dev/null

    mkdir -p $INSTALLDIR
    for file in bossac ; do
      rm -f $INSTALLDIR/$file ||:  2>/dev/null
      cp bin/$file $INSTALLDIR
      strip $INSTALLDIR/$file
      [ -n "$HOSTISDARWIN" ] && codesign -f -o runtime --timestamp -s 'Developer ID Application: Michael Ring (4S7HMLQE4Z)' $INSTALLDIR/$file
    done
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
buildbossa         arm-none-eabi    arm-embedded

rm -f develtools4fpc-$ARCHDIR.zip
rm -f binutils_gdb-$ARCHDIR.zip
mkdir -p cross/bin/arm-freertos
cp cross/bin/arm-embedded/* cross/bin/arm-freertos/
mkdir -p cross/bin/riscv32-freertos
cp cross/bin/riscv32-embedded/* cross/bin/riscv32-freertos/

zip -r develtools4fpc-$ARCHDIR.zip bin share |  $PV --name="Zipping  " --line-mode --size 827 >/dev/null
zip -r binutils_gdb-$ARCHDIR.zip  cross |  $PV --name="Zipping  " --line-mode --size 51 >/dev/null

