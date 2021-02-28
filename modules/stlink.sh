#!/bin/sh
buildstlink() {
  INSTALLDIR=$OUTPUTDIR/bin/
  EXEEXT=
  [ -n "$HOSTISWINDOWS" ] && EXEEXT=.exe

  if [ -n "$HOSTISWINDOWS" ]; then
    echo "Skipping $STLINKVERSION for target $TARGET, not supported..."
    return
  fi



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

    [ -n "$HOSTISLINUX"   ] && sudo apt-get install -y libusb-1.0-0-dev libudev-dev #2>/dev/null >/dev/null

  
    if [ -n "$HOSTISDARWIN" ]; then
      mkdir build
      cd build
      cmake .. 2>/dev/null | $PV --name="Cmake    " --line-mode --size 64 >/dev/null
      make -j 8 2>/dev/null | $PV --name="Build    " --line-mode --size 48 >/dev/null
      cd ..
    fi
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

      (
        cd /usr/src/mxe
        sudo make libusb1
      )

      mkdir build
      cd build
      cmake .. #-G "MinGW Makefiles" ..
      make -j 8
      #/mingw64/bin/cmake.exe -G "MinGW Makefiles" ..
      #/mingw64/bin/mingw32-make.exe
      #make release -j 8 2>/dev/null | $PV --name="Build    " --line-mode --size 113 >/dev/null
      cd ..
    fi
    mkdir -p $INSTALLDIR
    for file in st-flash${EXEEXT} st-info${EXEEXT} st-util${EXEEXT} ; do
      rm -f $INSTALLDIR/$file ||:  2>/dev/null
      cp build/bin/$file $INSTALLDIR
      strip $INSTALLDIR/$file
      [ -n "$HOSTISDARWIN" ] && codesign -f -o runtime --timestamp -s 'Developer ID Application: Michael Ring (4S7HMLQE4Z)' $INSTALLDIR/$file ||:
    done
  )
}