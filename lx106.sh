#! /bin/bash
set -ex

# Based off a great article here:
# http://preshing.com/20141119/how-to-build-a-gcc-cross-compiler/

ARCH=$1
PARALLEL_MAKE=$2
TARGET=xtensa-lx106-elf

if [ "$ARCH" = "linux64" ]; then
    BUILD=x86_64-build_unknown-linux-gnu
    HOST=x86_64-build_unknown-linux-gnu
elif [ "$ARCH" = "linux32" ]; then
    BUILD=x86_64-build_unknown-linux-gnu
    HOST=x86_64-build_unknown-linux-gnu
    CFLAGS=-m32
    LDFLAGS=-m32
elif [ "$ARCH" = "win32" ]; then
    BUILD=x86_64-build_unknown-linux-gnu
    HOST=i686-w64-mingw32
elif [ "$ARCH" = "win64" ]; then
    BUILD=x86_64-build_unknown-linux-gnu
    HOST=x86_64-w64-mingw32
elif [ "$ARCH" = "macosx" ]; then
    BUILD=x86_64-apple-darwin14.4.0
    HOST=x86_64-apple-darwin14.4.0
else
    echo Unknown arch: $ARCH
    exit
fi

BINUTILS_VERSION=binutils-2.27
GCC_VERSION=gcc-6.2.0
MPFR_VERSION=mpfr-3.1.4
GMP_VERSION=gmp-6.1.1
MPC_VERSION=mpc-1.0.3
ISL_VERSION=isl-0.16.1
GDB_VERSION=gdb-7.11.1

DOWNLOAD_DIR=$PWD/download
SRC_DIR=$PWD/src
BUILD_DIR=$PWD/build-$ARCH/$TARGET
INSTALL_DIR=$PWD/out-$ARCH/$TARGET
TAR_DIR=$PWD/tars

export PATH=$INSTALL_DIR/bin:$PATH

# Download packages
mkdir -p $DOWNLOAD_DIR
cd $DOWNLOAD_DIR
wget -nc https://ftp.gnu.org/gnu/binutils/$BINUTILS_VERSION.tar.gz
wget -nc https://ftp.gnu.org/gnu/gcc/$GCC_VERSION/$GCC_VERSION.tar.gz
wget -nc https://ftp.gnu.org/gnu/mpfr/$MPFR_VERSION.tar.xz
wget -nc https://ftp.gnu.org/gnu/gmp/$GMP_VERSION.tar.xz
wget -nc https://ftp.gnu.org/gnu/mpc/$MPC_VERSION.tar.gz
wget -nc ftp://gcc.gnu.org/pub/gcc/infrastructure/$ISL_VERSION.tar.bz2
wget -nc https://ftp.gnu.org/gnu/gdb/$GDB_VERSION.tar.xz

# Extract everything
mkdir -p $SRC_DIR
cd $SRC_DIR
[ -d $BINUTILS_VERSION ] || tar xf $DOWNLOAD_DIR/$BINUTILS_VERSION.tar.gz
[ -d $GCC_VERSION ] || tar xf $DOWNLOAD_DIR/$GCC_VERSION.tar.gz
[ -d $MPFR_VERSION ] || tar xf $DOWNLOAD_DIR/$MPFR_VERSION.tar.xz
[ -d $GMP_VERSION ] || tar xf $DOWNLOAD_DIR/$GMP_VERSION.tar.xz
[ -d $MPC_VERSION ] || tar xf $DOWNLOAD_DIR/$MPC_VERSION.tar.gz
[ -d $ISL_VERSION ] || tar xf $DOWNLOAD_DIR/$ISL_VERSION.tar.bz2
[ -d $GDB_VERSION ] || tar xf $DOWNLOAD_DIR/$GDB_VERSION.tar.xz

# Make symbolic links for gcc
cd $GCC_VERSION
ln -sf `ls -1d ../mpfr-*/` mpfr
ln -sf `ls -1d ../gmp-*/` gmp
ln -sf `ls -1d ../mpc-*/` mpc
ln -sf `ls -1d ../isl-*/` isl

# Binutils
if [ ! -d $BUILD_DIR/binutils ]; then
mkdir -p $BUILD_DIR/binutils
cd $BUILD_DIR/binutils
CFLAGS=$CFLAGS LDFLAGS=$LDFLAGS $SRC_DIR/$BINUTILS_VERSION/configure \
    --prefix=$INSTALL_DIR \
    --build=$BUILD \
    --host=$HOST \
    --target=$TARGET
make $PARALLEL_MAKE
make install
fi

# C/C++ Compilers
if [ ! -d $BUILD_DIR/gcc ]; then
mkdir -p $BUILD_DIR/gcc
cd $BUILD_DIR/gcc
CXXFLAGS=$CFLAGS CFLAGS=$CFLAGS LDFLAGS=$LDFLAGS $SRC_DIR/$GCC_VERSION/configure \
    --prefix=$INSTALL_DIR \
    --build=$BUILD \
    --host=$HOST \
    --target=$TARGET \
    --enable-languages=c,c++
make $PARALLEL_MAKE all-gcc
make install-gcc
fi

# gdb
if [ ! -d $BUILD_DIR/gdb ]; then
mkdir -p $BUILD_DIR/gdb
cd $BUILD_DIR/gdb
CXXFLAGS=$CFLAGS CFLAGS=$CFLAGS LDFLAGS=$LDFLAGS $SRC_DIR/$GDB_VERSION/configure \
    --prefix=$INSTALL_DIR \
    --build=$BUILD \
    --host=$HOST \
    --target=$TARGET
make $PARALLEL_MAKE
make install
fi

mkdir -p $TAR_DIR
cd $INSTALL_DIR/..
tar jcf $TAR_DIR/$TARGET-$ARCH.tar.bz2 $TARGET
