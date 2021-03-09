buildopenocdrp2040() {
  INSTALLDIR=$OUTPUTDIR/bin/
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
    git clone https://github.com/raspberrypi/openocd.git --branch picoprobe --depth=1 openocd-rp2040 2>&1 | $PV --name="Cloning  " --line-mode --size 2 >/dev/null
    cd $OPENOCDRP2040VERSION

    [ -n "$HOSTISLINUX"   ] && sudo apt-get install -y libusb-1.0-0-dev libudev-dev libhidapi-dev libftdi-dev 2>/dev/null >/dev/null

    ./bootstrap 2>&1 | $PV --name="Bootstrap" --line-mode --size 44 >/dev/null

    mkdir build
    cd build

    CONFIGUREFLAGS="--enable-static --disable-shared --enable-picoprobe --disable-werror"
    [ -n "$HOSTISDARWIN" ]  && ../configure $CONFIGUREFLAGS 2>/dev/null | $PV --name="Configure" --line-mode --size 438 >/dev/null
    [ -n "$HOSTISLINUX" ]   && ../configure $CONFIGUREFLAGS 2>/dev/null | $PV --name="Configure" --line-mode --size 438 >/dev/null
    if [ -n "$HOSTISWINDOWS" ]; then
      (
        cd /usr/src/mxe
        sudo make hidapi
        sudo make libusb1
        sudo make libftdi1
      )
      [ -n "$HOSTISWINDOWSX86_64" ] && PKG_CONFIG_PATH=/usr/src/mxe/usr/x86_64-w64-mingw32.static/lib/pkgconfig/ ../configure $CONFIGUREFLAGS --host=x86_64-w64-mingw32 2>/dev/null | $PV --name="Configure" --line-mode --size 438 >/dev/null
      [ -n "$HOSTISWINDOWSI686" ] && PKG_CONFIG_PATH=/usr/src/mxe/usr/i686-w64-mingw32.static/lib/pkgconfig/ ../configure $CONFIGUREFLAGS --host=i686-w64-mingw32 2>/dev/null | $PV --name="Configure" --line-mode --size 438 >/dev/null
    fi
  
    [ -n "$HOSTISDARWIN"  ] && make -j 8 INFO_DEPS= CAPSTONE_CFLAGS=-I/opt/homebrew/Cellar/capstone/4.0.2/include/ 2>/dev/null | $PV --name="Build    " --line-mode --size 1250 >/dev/null
    [ -n "$HOSTISLINUX"   ] && make -j 8 INFO_DEPS= 2>/dev/null | $PV --name="Build    " --line-mode --size 1230 >/dev/null
    [ -n "$HOSTISWINDOWS" ] && make -j 8 INFO_DEPS= 2>/dev/null | $PV --name="Build    " --line-mode --size 1250 >/dev/null

    [ -n "$HOSTISDARWINX86_64" ] && gcc -Wall -Wstrict-prototypes -Wformat-security -Wshadow -Wextra -Wno-unused-parameter -Wbad-function-cast -Wcast-align -Wredundant-decls -g -O2 -o src/openocd src/main.o src/.libs/libopenocd.a /usr/local/opt/libusb-compat/lib/libusb.a /usr/local/opt/libftdi/lib/libftdi1.a /usr/local/opt/hidapi/lib/libhidapi.a /usr/local/opt/libusb/lib/libusb-1.0.a -lobjc -Wl,-framework,IOKit -Wl,-framework,CoreFoundation -Wl,-framework,AppKit -lm ./jimtcl/libjim.a
    [ -n "$HOSTISDARWINARM64" ]  && gcc -Wall -Wstrict-prototypes -Wformat-security -Wshadow -Wextra -Wno-unused-parameter -Wbad-function-cast -Wcast-align -Wredundant-decls -g -O2 -o src/openocd src/main.o src/.libs/libopenocd.a                /opt/homebrew/lib/libusb.a          /opt/homebrew/lib/libftdi1.a         /opt/homebrew/lib/libhidapi.a         /opt/homebrew/lib/libusb-1.0.a -lobjc -Wl,-framework,IOKit -Wl,-framework,CoreFoundation -Wl,-framework,AppKit -lm /opt/homebrew/Cellar/capstone/4.0.2/lib/libcapstone.a ./jimtcl/libjim.a
    [ -n "$HOSTISLINUX"   ]      && /usr/bin/x86_64-linux-gnu-gcc -Wall -Wstrict-prototypes -Wformat-security -Wshadow -Wextra -Wno-unused-parameter -Wbad-function-cast -Wcast-align -Wredundant-decls -g -O2 -o src/openocd src/main.o  src/.libs/libopenocd.a -ludev -lpthread /usr/lib/x86_64-linux-gnu/libusb-1.0.a -ludev -lpthread -lm ./jimtcl/libjim.a -ldl

    make install DESTDIR=$BUILDDIR 2>/dev/null | $PV --name="Install  " --line-mode --size 87 >/dev/null

    mkdir -p $INSTALLDIR
    for file in openocd-rp2040${EXEEXT} ; do
      rm -f $INSTALLDIR/${file} ||:  2>/dev/null
      cp $BUILDDIR/$PREFIXDIR/bin/openocd${EXEEXT} $INSTALLDIR/${file}
      strip $INSTALLDIR/${file}
      [ -n "$HOSTISDARWIN" ] && codesign -f -o runtime --timestamp -s 'Developer ID Application: Michael Ring (4S7HMLQE4Z)' $INSTALLDIR/${file}
    done

    mkdir -p $INSTALLDIR/../share/openocd/scripts/board
    mkdir -p $INSTALLDIR/../share/openocd/scripts/interface
    mkdir -p $INSTALLDIR/../share/openocd/scripts/target
    cp $BUILDDIR/$PREFIXDIR/share/openocd/scripts/interface/picoprobe.cfg $INSTALLDIR/../share/openocd/scripts/interface/
    cp $BUILDDIR/$PREFIXDIR/share/openocd/scripts/target/rp2040*.cfg $INSTALLDIR/../share/openocd/scripts/target/
    cp $BUILDDIR/$PREFIXDIR/share/openocd/scripts/target/swj-dp*.tcl $INSTALLDIR/../share/openocd/scripts/target/
    cat >$INSTALLDIR/../share/openocd/scripts/board/pico.cfg <<EOF
source [find interface/picoprobe.cfg]
source [find target/RP2040.cfg]    
EOF
    rm -rf $BUILDDIR/$PREFIXDIR
  )
}
