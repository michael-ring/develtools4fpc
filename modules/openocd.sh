buildopenocd() {
  INSTALLDIR=$OUTPUTDIR/bin/
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
    git clone https://github.com/ntfreak/openocd.git openocd-0.11.0 2>&1 | $PV --name="Cloning  " --line-mode --size 2 >/dev/null
    cd $OPENOCDVERSION

    [ -n "$HOSTISLINUX"   ] && sudo apt-get install -y libusb-1.0-0-dev libudev-dev 2>/dev/null >/dev/null

    ./bootstrap 2>&1 | $PV --name="Bootstrap" --line-mode --size 42 >/dev/null

    mkdir build
    cd build

    CONFIGUREFLAGS="--enable-static --disable-shared --disable-werror --without-capstone"
    [ -n "$HOSTISDARWIN"  ] && ../configure $CONFIGUREFLAGS 2>/dev/null | $PV --name="Configure" --line-mode --size 439 >/dev/null
    [ -n "$HOSTISLINUX"   ] && ../configure $CONFIGUREFLAGS 2>/dev/null | $PV --name="Configure" --line-mode --size 420 >/dev/null
    if [ -n "$HOSTISWINDOWS" ]; then
      (
        cd /usr/src/mxe
        sudo make hidapi
        sudo make libusb1
        sudo make libftdi1
      )
      PKG_CONFIG_PATH=/usr/src/mxe/usr/x86_64-w64-mingw32.static/lib/pkgconfig/ ../configure $CONFIGUREFLAGS --host=x86_64-w64-mingw32 2>/dev/null | $PV --name="Configure" --line-mode --size 439 >/dev/null
    fi
  
    [ -n "$HOSTISDARWIN"  ] && make -j 8 INFO_DEPS= 2>/dev/null | $PV --name="Build    " --line-mode --size 1250 >/dev/null
    [ -n "$HOSTISLINUX"   ] && make -j 8 INFO_DEPS= 2>/dev/null | $PV --name="Build    " --line-mode --size 1120 >/dev/null
    [ -n "$HOSTISWINDOWS" ] && make -j 8 INFO_DEPS= 2>/dev/null | $PV --name="Build    " --line-mode --size 1250 >/dev/null

    [ -n "$HOSTISDARWINX86_64" ]  && gcc -Wall -Wstrict-prototypes -Wformat-security -Wshadow -Wextra -Wno-unused-parameter -Wbad-function-cast -Wcast-align -Wredundant-decls -Wpointer-arith -g -O2 -o src/openocd src/main.o src/.libs/libopenocd.a /usr/local/opt/libusb-compat/lib/libusb.a /usr/local/opt/libftdi/lib/libftdi1.a /usr/local/opt/hidapi/lib/libhidapi.a /usr/local/opt/libusb/lib/libusb-1.0.a -lobjc -Wl,-framework,IOKit -Wl,-framework,CoreFoundation -Wl,-framework,AppKit -lm ./jimtcl/libjim.a
    [ -n "$HOSTISDARWINARM64" ] && gcc -Wall -Wstrict-prototypes -Wformat-security -Wshadow -Wextra -Wno-unused-parameter -Wbad-function-cast -Wcast-align -Wredundant-decls -Wpointer-arith -g -O2 -o src/openocd src/main.o src/.libs/libopenocd.a                /opt/homebrew/lib/libusb.a          /opt/homebrew/lib/libftdi1.a         /opt/homebrew/lib/libhidapi.a         /opt/homebrew/lib/libusb-1.0.a -lobjc -Wl,-framework,IOKit -Wl,-framework,CoreFoundation -Wl,-framework,AppKit -lm ./jimtcl/libjim.a
    [ -n "$HOSTISLINUX"   ]      && /usr/bin/x86_64-linux-gnu-gcc -Wall -Wstrict-prototypes -Wformat-security -Wshadow -Wextra -Wno-unused-parameter -Wbad-function-cast -Wcast-align -Wredundant-decls -Wpointer-arith -g -O2 -o src/openocd src/main.o  src/.libs/libopenocd.a -ludev -lpthread /usr/lib/x86_64-linux-gnu/libusb-1.0.a -ludev -lpthread -lm ./jimtcl/libjim.a -ldl

    make install INFO_DEPS= DESTDIR=$BUILDDIR 2>/dev/null | $PV --name="Install  " --line-mode --size 44 >/dev/null

    mkdir -p $INSTALLDIR
    for file in openocd${EXEEXT} ; do
      rm -f $INSTALLDIR/${file} ||:  2>/dev/null
      cp $BUILDDIR/$PREFIXDIR/bin/openocd${EXEEXT} $INSTALLDIR/${file}
      strip $INSTALLDIR/${file}
      [ -n "$HOSTISDARWIN" ] && codesign -f -o runtime --timestamp -s 'Developer ID Application: Michael Ring (4S7HMLQE4Z)' $INSTALLDIR/${file}
    done
    mkdir -p $INSTALLDIR/../share/openocd
    cp -r $BUILDDIR/$PREFIXDIR/share/openocd $INSTALLDIR/../share/
    rm -rf $BUILDDIR/$PREFIXDIR
  )
}
