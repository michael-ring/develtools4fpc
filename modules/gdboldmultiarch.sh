#!/bin/sh
buildgdboldmultiarch() {
  TARGETS=$1
  DESTSUBDIR=$2
  INSTALLDIR=$OUTPUTDIR/bin/
  EXEEXT=
  [ -n "$HOSTISWINDOWS" ] && EXEEXT=.exe

  if [ -f $INSTALLDIR/gdb-multiarch-8.3.1${EXEEXT} ]; then
    echo "Skipping $GDBOLDVERSION for targets $TARGETS..."
    return 0
  else
    echo "Building $GDBOLDVERSION for targets $TARGETS..."
  fi
  (
    [ -d $GDBOLDVERSION ] && rm -rf $GDBOLDVERSION
    tar zxvf ${GDBOLDVERSION}.tar.gz 2>&1 | $PV --name="Unpack   " --line-mode --size 12500 >/dev/null
    cd $GDBOLDVERSION

    [ -n "$HOSTISLINUX"   ] && sudo apt-get install -y libexpat-dev texinfo 2>/dev/null >/dev/null

    [ -n "$HOSTISDARWIN" ] && patch -p1 <../patches/gdb-darwin.patch
    
    if [ -n "$HOSTISWINDOWS" ]; then
      (
        cd /usr/src/mxe
        sudo make libiconv
        sudo make expat
      )
      patch -p1 <../patches/gdb-8.3.1-makeinfo.patch
    fi

    HOST=$(./config.guess)

    mkdir build
    cd build

    CONFIGUREFLAGS="--target=$HOST --enable-targets=$TARGETS --disable-shared --enable-static --disable-werror --without-curses \
                    --disable-tui --with-expat --without-babeltrace --disable-unit-tests --disable-source-highlight \
                    --disable-xz --disable-xzdec --disable-lzmadec --disable-scripts \
                    --disable-doc --disable-docs --disable-nls --disable-rpath --disable-libmcheck --without-libunwind \
                    --without-mpc --without-mpfr --without-gmp --without-cloog --without-isl \
                    --disable-sim --enable-gdbserver=no --without-python  --disable-gprof --without-debuginfod \
                    --without-guile --without-lzma --without-xxhash --without-intel-pt --disable-inprocess-agent"
    [ -n "$HOSTISDARWIN" ]  && CFLAGS="-Wno-error=implicit-function-declaration" ../configure $CONFIGUREFLAGS --host=$HOST 2>/dev/null | $PV --name="Configure" --line-mode --size 139 >/dev/null
    [ -n "$HOSTISLINUX" ]   && CFLAGS="-DNDEBUG -static-libstdc++ -static-libgcc" CXXFLAGS="-DNDEBUG -static-libstdc++ -static-libgcc" ../configure $CONFIGUREFLAGS --host=$HOST 2>/dev/null | $PV --name="Configure" --line-mode --size 124 >/dev/null
    [ -n "$HOSTISWINDOWS" ] && ../configure $CONFIGUREFLAGS --host=x86_64-w64-mingw32 2>/dev/null | $PV --name="Configure" --line-mode --size 96 >/dev/null
  
    [ -n "$HOSTISDARWIN"  ] && make -j 8 2>/dev/null | $PV --name="Build    " --line-mode --size 3590 >/dev/null
    [ -n "$HOSTISLINUX"   ] && make -j 8 2>/dev/null | $PV --name="Build    " --line-mode --size 3740 >/dev/null
    [ -n "$HOSTISWINDOWS" ] && make -j 8 2>/dev/null #| $PV --name="Build    " --line-mode --size 3740 >/dev/null

    if [ -n "$HOSTISLINUX" ]; then
      cd gdb
      rm -f gdb
      sed --in-place "s,-ltermcap,/usr/lib/x86_64-linux-gnu/libtermcap.a,g" Makefile
      sed --in-place "s,-lexpat,/usr/lib/x86_64-linux-gnu/libexpat.a,g" Makefile
      make | $PV --name="Relink   " --line-mode --size 46 >/dev/null
    fi

    make install DESTDIR=$BUILDDIR 2>/dev/null | $PV --name="Install  " --line-mode --size 190 >/dev/null

    mkdir -p $INSTALLDIR
    for file in gdb-multiarch-8.3.1${EXEEXT} ; do
      rm -f $INSTALLDIR/$file ||:  2>/dev/null
      cp $BUILDDIR/$PREFIXDIR/bin/*gdb${EXEEXT} $INSTALLDIR/$file
      strip $INSTALLDIR/$file
      [ -n "$HOSTISDARWIN" ] && codesign -f -o runtime --timestamp -s 'Developer ID Application: Michael Ring (4S7HMLQE4Z)' $INSTALLDIR/$file
    done
    rm -rf $BUILDDIR/$PREFIXDIR
  )
}
