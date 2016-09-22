#! /bin/bash
set -ex

# Based off a great article here:
# http://preshing.com/20141119/how-to-build-a-gcc-cross-compiler/

ARCH=$1
PARALLEL_MAKE=$2
TARGET=xtensa-elf32-elf

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
    export CC=gcc-5
    export CXX=g++-5
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

INSTALL_PATH=$PWD/out-$ARCH
export PATH=$INSTALL_PATH/bin:$PWD/out-$MAIN/bin:$PATH

# Download packages
mkdir -p download
cd download
wget -nc https://ftp.gnu.org/gnu/binutils/$BINUTILS_VERSION.tar.gz
wget -nc https://ftp.gnu.org/gnu/gcc/$GCC_VERSION/$GCC_VERSION.tar.gz
wget -nc https://ftp.gnu.org/gnu/mpfr/$MPFR_VERSION.tar.xz
wget -nc https://ftp.gnu.org/gnu/gmp/$GMP_VERSION.tar.xz
wget -nc https://ftp.gnu.org/gnu/mpc/$MPC_VERSION.tar.gz
wget -nc ftp://gcc.gnu.org/pub/gcc/infrastructure/$ISL_VERSION.tar.bz2
wget -nc https://ftp.gnu.org/gnu/gdb/$GDB_VERSION.tar.xz
cd ..

# Extract everything
mkdir -p src
cd src
[ -d $BINUTILS_VERSION ] || tar xf ../download/$BINUTILS_VERSION.tar.gz
[ -d $GCC_VERSION ] || tar xf ../download/$GCC_VERSION.tar.gz
[ -d $MPFR_VERSION ] || tar xf ../download/$MPFR_VERSION.tar.xz
[ -d $GMP_VERSION ] || tar xf ../download/$GMP_VERSION.tar.xz
[ -d $MPC_VERSION ] || tar xf ../download/$MPC_VERSION.tar.gz
[ -d $ISL_VERSION ] || tar xf ../download/$ISL_VERSION.tar.bz2
if [ "$ARCH" = "$MAIN" ]; then
[ -d $LINUX_KERNEL_VERSION ] || tar xf ../download/$LINUX_KERNEL_VERSION.tar.xz
[ -d $GLIBC_VERSION ] || tar xf ../download/$GLIBC_VERSION.tar.xz
fi
[ -d $GDB_VERSION ] || tar xf ../download/$GDB_VERSION.tar.xz

# Make symbolic links for gcc
cd $GCC_VERSION
ln -sf `ls -1d ../mpfr-*/` mpfr
ln -sf `ls -1d ../gmp-*/` gmp
ln -sf `ls -1d ../mpc-*/` mpc
ln -sf `ls -1d ../isl-*/` isl
cd ..
cd ..

# Binutils
if [ ! -d build-$ARCH/binutils ]; then
mkdir -p build-$ARCH/binutils
cd build-$ARCH/binutils
CFLAGS=$CFLAGS LDFLAGS=$LDFLAGS ../../src/$BINUTILS_VERSION/configure \
    --prefix=$INSTALL_PATH \
    --build=$BUILD \
    --host=$HOST \
    --target=$TARGET
make $PARALLEL_MAKE
make install
cd ../..
fi

# C/C++ Compilers
if [ ! -d build-$ARCH/gcc ]; then
mkdir -p build-$ARCH/gcc
cd build-$ARCH/gcc
CXXFLAGS=$CFLAGS CFLAGS=$CFLAGS LDFLAGS=$LDFLAGS ../../src/$GCC_VERSION/configure \
    --prefix=$INSTALL_PATH \
    --build=$BUILD \
    --host=$HOST \
    --target=$TARGET \
    --enable-languages=c,c++
make $PARALLEL_MAKE all-gcc
make install-gcc
cd ../..
fi

# gdb
if [ ! -d build-$ARCH/gdb ]; then
mkdir -p build-$ARCH/gdb
cd build-$ARCH/gdb
CXXFLAGS=$CFLAGS CFLAGS=$CFLAGS LDFLAGS=$LDFLAGS ../../src/$GDB_VERSION/configure \
    --prefix=$INSTALL_PATH \
    --build=$BUILD \
    --host=$HOST \
    --target=$TARGET
make $PARALLEL_MAKE
make install
cd ../..
fi
