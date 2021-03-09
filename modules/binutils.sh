#!/bin/sh
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
    [ ! -d $BINUTILSVERSION ] && tar zxvf ${BINUTILSVERSION}.tar.gz 2>&1 | $PV --name="Unpack   " --line-mode --size 25100 >/dev/null
    [ -d $BINUTILSVERSION/build ] && rm -rf $BINUTILSVERSION/build
    cd $BINUTILSVERSION
    mkdir build
    cd build
    CONFIGUREFLAGS="--target=$TARGET --enable-static --disable-shared --disable-nls --program-prefix=${PROGRAMPREFIX}-"
    [ -n "$HOSTISDARWIN"  ] && ../configure $CONFIGUREFLAGS 2>/dev/null | $PV --name="Configure" --line-mode --size 97 >/dev/null
    [ -n "$HOSTISLINUX"   ] && ../configure $CONFIGUREFLAGS 2>/dev/null | $PV --name="Configure" --line-mode --size 97 >/dev/null
    [ -n "$HOSTISWINDOWSX86_64" ] && ../configure $CONFIGUREFLAGS --host=x86_64-w64-mingw32 2>/dev/null | $PV --name="Configure" --line-mode --size 94 >/dev/null
    [ -n "$HOSTISWINDOWSI686" ] && ../configure $CONFIGUREFLAGS --host=i686-w64-mingw32 2>/dev/null | $PV --name="Configure" --line-mode --size 94 >/dev/null
  
    [ -n "$HOSTISDARWIN"  ] && make -j 8 2>/dev/null | $PV --name="Build    " --line-mode --size 3060 >/dev/null
    [ -n "$HOSTISLINUX"   ] && make -j 8 2>/dev/null | $PV --name="Build    " --line-mode --size 3090 >/dev/null
    [ -n "$HOSTISWINDOWS" ] && make -j 8 2>/dev/null | $PV --name="Build    " --line-mode --size 3006 >/dev/null

    [ -n "$HOSTISDARWIN"  ] && make install DESTDIR=$BUILDDIR 2>/dev/null | $PV --name="Install  " --line-mode --size 173 >/dev/null
    [ -n "$HOSTISLINUX"   ] && make install DESTDIR=$BUILDDIR 2>/dev/null | $PV --name="Install  " --line-mode --size 248 >/dev/null
    [ -n "$HOSTISWINDOWS" ] && make install DESTDIR=$BUILDDIR 2>/dev/null | $PV --name="Install  " --line-mode --size 167 >/dev/null

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
