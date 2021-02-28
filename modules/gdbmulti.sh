#!/bin/sh
buildgdbmultiarch() {
  TARGET=$1
  DESTSUBDIR=$2
  INSTALLDIR=$OUTPUTDIR/bin/
  EXEEXT=
  [ -n "$HOSTISWINDOWS" ] && EXEEXT=.exe

  if [ -f $INSTALLDIR/gdbmulti${EXEEXT} ]; then
    echo "Skipping $GDBVERSION for targets $TARGET..."
    return 0
  else
    echo "Building $GDBVERSION for targets $TARGET..."
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
    [ -n "$HOSTISDARWIN" ]  &&../configure $CONFIGUREFLAGS 2>/dev/null | $PV --name="Configure" --line-mode --size 96 >/dev/null
    [ -n "$HOSTISLINUX" ]   && CFLAGS="-DNDEBUG -static-libstdc++ -static-libgcc" CXXFLAGS="-DNDEBUG -static-libstdc++ -static-libgcc" ../configure $CONFIGUREFLAGS 2>/dev/null | $PV --name="Configure" --line-mode --size 96 >/dev/null
    [ -n "$HOSTISWINDOWS" ] && CFLAGS=-DNDEBUG CXXFLAGS=-DNDEBUG ../configure $CONFIGUREFLAGS --with-system-readline 2>/dev/null | $PV --name="Configure" --line-mode --size 96 >/dev/null
  
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
