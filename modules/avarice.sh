buildavarice() {
  [ -z "$PROGRAMPREFIX" ] && PROGRAMPREFIX=${TARGET}
  INSTALLDIR=$OUTPUTDIR/bin/
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

    CONFIGUREFLAGS="--disable-shared --enable-static --disable-werror"
    [ -n "$HOSTISDARWIN" ] && ../configure $CONFIGUREFLAGS 2>/dev/null | $PV --name="Configure" --line-mode --size 129 >/dev/null
    [ -n "$HOSTISLINUX" ] && CFLAGS="-DNDEBUG -static-libstdc++ -static-libgcc" CXXFLAGS="-DNDEBUG -static-libstdc++ -static-libgcc" ../configure $CONFIGUREFLAGS 2>/dev/null | $PV --name="Configure" --line-mode --size 129 >/dev/null
    [ -n "$HOSTISWINDOWS" ] && ../configure $CONFIGUREFLAGS --host=x86_64-w64-mingw32 2>/dev/null | $PV --name="Configure" --line-mode --size 129 >/dev/null
  
    [ -n "$HOSTISDARWIN"  ] && make -j 8 2>/dev/null | $PV --name="Build    " --line-mode --size 64 >/dev/null
    [ -n "$HOSTISLINUX"   ] && make -j 8 2>/dev/null | $PV --name="Build    " --line-mode --size 80 >/dev/null
    [ -n "$HOSTISWINDOWS" ] && make -j 8 2>/dev/null | $PV --name="Build    " --line-mode --size 80 >/dev/null

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
