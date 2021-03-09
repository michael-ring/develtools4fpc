#!/bin/sh
buildgdbmultiarch() {
  TARGETS=$1
  DESTSUBDIR=$2
  INSTALLDIR=$OUTPUTDIR/bin/
  EXEEXT=
  [ -n "$HOSTISWINDOWS" ] && EXEEXT=.exe

  if [ -f $INSTALLDIR/gdb-multiarch${EXEEXT} ]; then
    echo "Skipping $GDBVERSION for targets $TARGETS..."
    return 0
  else
    echo "Building $GDBVERSION for targets $TARGETS..."
  fi
  (
    [ -d $GDBVERSION ] && rm -rf $GDBVERSION
    tar zxvf ${GDBVERSION}.tar.gz 2>&1 | $PV --name="Unpack   " --line-mode --size 13100 >/dev/null
    cd $GDBVERSION

    [ -n "$HOSTISLINUX"   ] && sudo apt-get install -y libexpat-dev texinfo 2>/dev/null >/dev/null

    [ -n "$HOSTISDARWIN" ] && patch -p1 <../patches/gdb-darwin.patch

    if [ -n "$HOSTISWINDOWS" ]; then
      (
      cd /usr/src/mxe
      sudo make libiconv
      sudo make expat
      )
      patch -p1 <../patches/gdb-makeinfo.patch
    fi

    HOST=$(./config.guess)

    mkdir build
    cd build

    CONFIGUREFLAGS="--enable-targets=$TARGETS --disable-shared --enable-static --disable-werror --without-curses \
                    --disable-tui --with-expat --without-babeltrace --disable-unit-tests --disable-source-highlight \
                    --disable-xz --disable-xzdec --disable-lzmadec --disable-scripts \
                    --disable-doc --disable-docs --disable-nls --disable-rpath --disable-libmcheck --without-libunwind \
                    --without-mpc --without-mpfr --without-gmp --without-cloog --without-isl \
                    --disable-sim --enable-gdbserver=no --without-python  --disable-gprof --without-debuginfod \
                    --without-guile --without-lzma --without-xxhash --without-intel-pt --disable-inprocess-agent"
    [ -n "$HOSTISDARWINX86_64" ]  && LDFLAGS="-Wl,-macosx_version_min,10.8" ../configure $CONFIGUREFLAGS --target=$HOST 2>/dev/null | $PV --name="Configure" --line-mode --size 139 >/dev/null
    [ -n "$HOSTISDARWINARM64"  ]  && LDFLAGS="-Wl,-macosx_version_min,10.8" ../configure $CONFIGUREFLAGS --target=arm-none-eabi 2>/dev/null | $PV --name="Configure" --line-mode --size 139 >/dev/null
    [ -n "$HOSTISLINUX"        ]   && CFLAGS="-DNDEBUG -static-libstdc++ -static-libgcc" CXXFLAGS="-DNDEBUG -static-libstdc++ -static-libgcc" ../configure $CONFIGUREFLAGS --target=$HOST 2>/dev/null | $PV --name="Configure" --line-mode --size 124 >/dev/null
    if [ -n "$HOSTISWINDOWSX86_64" ]; then
      CFLAGS=-DNDEBUG CXXFLAGS=-DNDEBUG ../configure --host=x86_64-w64-mingw32 $CONFIGUREFLAGS --target=x86_64-w64-mingw32 2>/dev/null | $PV --name="Configure" --line-mode --size 96 >/dev/null
    fi
    if [ -n "$HOSTISWINDOWSI686" ]; then
      CFLAGS=-DNDEBUG CXXFLAGS=-DNDEBUG ../configure --host=i686-w64-mingw32 $CONFIGUREFLAGS --target=i686-w64-mingw32 2>/dev/null | $PV --name="Configure" --line-mode --size 96 >/dev/null
    fi
    [ -n "$HOSTISDARWIN"  ] && make -j 8 2>/dev/null | $PV --name="Build    " --line-mode --size 3860 >/dev/null
    [ -n "$HOSTISLINUX"   ] && make -j 8 2>/dev/null | $PV --name="Build    " --line-mode --size 3740 >/dev/null
    [ -n "$HOSTISWINDOWS" ] && make -j 8 ||: 2>/dev/null | $PV --name="Build    " --line-mode --size 3740 >/dev/null
    if [ -n "$HOSTISLINUX" ]; then
      cd gdb
      rm -f gdb
      sed --in-place "s,-ltermcap,/usr/lib/x86_64-linux-gnu/libtermcap.a,g" Makefile
      sed --in-place "s,-lexpat,/usr/lib/x86_64-linux-gnu/libexpat.a,g" Makefile
      make | $PV --name="Relink   " --line-mode --size 100 >/dev/null
    fi

    make install DESTDIR=$BUILDDIR 2>/dev/null | $PV --name="Install  " --line-mode --size 190 >/dev/null

    mkdir -p $INSTALLDIR
    for file in gdb-multiarch${EXEEXT} ; do
      rm -f $INSTALLDIR/$file ||:  2>/dev/null
      cp $BUILDDIR/$PREFIXDIR/bin/*gdb${EXEEXT} $INSTALLDIR/$file
      strip $INSTALLDIR/$file
      [ -n "$HOSTISDARWIN" ] && codesign -f -o runtime --timestamp -s 'Developer ID Application: Michael Ring (4S7HMLQE4Z)' $INSTALLDIR/$file
    done
    rm -rf $BUILDDIR/$PREFIXDIR
  )
}
