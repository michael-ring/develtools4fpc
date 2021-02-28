buildbossa() {
  INSTALLDIR=$OUTPUTDIR/bin/
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
    [ -n "$HOSTISDARWIN" ] && make bin/bossac 2>&1 | $PV --name="Building " --line-mode --size 18 >/dev/null
    [ -n "$HOSTISLINUX" ] && CFLAGS="-DNDEBUG -static-libstdc++ -static-libgcc" CXXFLAGS="-DNDEBUG -static-libstdc++ -static-libgcc" make bin/bossac  2>&1 | $PV --name="Building " --line-mode --size 18 >/dev/null
    if [ -n "$HOSTISWINDOWS" ]; then
      (
        cd /usr/src/mxe
        sudo make termcap
      )

      make OS=MINGW32 bin/bossac.exe 2>&1 | $PV --name="Building " --line-mode --size 18 >/dev/null
    fi

    mkdir -p $INSTALLDIR
    for file in bossac${EXEEXT} ; do
      rm -f $INSTALLDIR/$file ||:  2>/dev/null
      cp bin/bossac${EXEEXT} $INSTALLDIR
      strip $INSTALLDIR/$file
      [ -n "$HOSTISDARWIN" ] && codesign -f -o runtime --timestamp -s 'Developer ID Application: Michael Ring (4S7HMLQE4Z)' $INSTALLDIR/$file
    done
  )
}
