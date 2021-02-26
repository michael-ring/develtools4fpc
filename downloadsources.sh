#!/bin/sh

[ ! -f binutils-2.36.1.tar.gz ] && curl -L https://ftp.gnu.org/gnu/binutils/binutils-2.36.1.tar.gz --output binutils-2.36.1.tar.gz
[ ! -f gdb-10.1.tar.gz ] && curl -L https://ftp.gnu.org/gnu/gdb/gdb-10.1.tar.gz --output gdb-10.1.tar.gz
[ ! -f AVaRICE-master.tar.gz ] && curl -L https://gitlab.cs.fau.de/i4/spic/tools/AVaRICE/-/archive/master/AVaRICE-master.tar.gz --output AVaRICE-master.tar.gz
[ ! -f stlink-1.6.1.tar.gz ] && curl -L https://github.com/stlink-org/stlink/archive/v1.6.1.tar.gz --output stlink-1.6.1.tar.gz
[ ! -f BOSSA-1.9.1.tar.gz ] && curl -L https://github.com/shumatech/BOSSA/archive/1.9.1.tar.gz --output BOSSA-1.9.1.tar.gz
#[ ! -f openocd-rp2040.zip ] && curl -L https://github.com/raspberrypi/openocd/archive/rp2040.zip --output openocd-rp2040.zip
