#! /bin/bash
set -ex

# Based off a great article here:
# http://preshing.com/20141119/how-to-build-a-gcc-cross-compiler/

ARCH=$1
PARALLEL_MAKE=$2
TARGET=arm-linux-gnueabihf
LINUX_ARCH=arm
MAIN=linux64

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

BINUTILS_VERSION=binutils-2.25
GCC_VERSION=gcc-5.1.0
MPFR_VERSION=mpfr-3.1.2
GMP_VERSION=gmp-6.0.0a
MPC_VERSION=mpc-1.0.2
ISL_VERSION=isl-0.14.1
LINUX_KERNEL_VERSION=linux-3.17.2
GLIBC_VERSION=glibc-2.21
GDB_VERSION=gdb-7.10

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
wget -nc http://isl.gforge.inria.fr/$ISL_VERSION.tar.bz2
if [ "$ARCH" = "$MAIN" ]; then
wget -nc https://www.kernel.org/pub/linux/kernel/v3.x/$LINUX_KERNEL_VERSION.tar.xz
wget -nc https://ftp.gnu.org/gnu/glibc/$GLIBC_VERSION.tar.xz
fi
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
    --enable-languages=c,c++ \
    --with-arch=armv6 --with-fpu=vfp --with-float=hard
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

# If not main arch, done
if [ "$ARCH" != "$MAIN" ]; then
exit
fi

# Linux Kernel Headers
if [ ! -d build-$ARCH/linux ]; then
mkdir -p build-$ARCH/linux
cd src/$LINUX_KERNEL_VERSION
make ARCH=$LINUX_ARCH \
    O=../build-$ARCH/linux \
    INSTALL_HDR_PATH=$INSTALL_PATH/$TARGET \
    headers_install
cd ../..
fi

# Standard C Library Headers and Startup Files
if [ ! -d build-$ARCH/glibc ]; then
mkdir -p build-$ARCH/glibc
cd build-$ARCH/glibc
../../src/$GLIBC_VERSION/configure \
    --prefix=$INSTALL_PATH/$TARGET \
    --build=$BUILD \
    --host=$TARGET \
    --target=$TARGET \
    --with-headers=$INSTALL_PATH/$TARGET/include \
    libc_cv_forced_unwind=yes
make install-bootstrap-headers=yes install-headers
make $PARALLEL_MAKE csu/subdir_lib
install csu/crt1.o csu/crti.o csu/crtn.o $INSTALL_PATH/$TARGET/lib
$TARGET-gcc -nostdlib -nostartfiles -shared -x c /dev/null -o $INSTALL_PATH/$TARGET/lib/libc.so
touch $INSTALL_PATH/$TARGET/include/gnu/stubs.h
cd ../..

# Compiler Support Library
cd build-$ARCH/gcc
make $PARALLEL_MAKE all-target-libgcc
make install-target-libgcc
cd ../..

# Standard C Library & the rest of Glibc
cd build-$ARCH/glibc
make $PARALLEL_MAKE
make install
cd ../..

# Standard C++ Library & the rest of GCC
cd build-$ARCH/gcc
make $PARALLEL_MAKE all
make install
cd ../..
fi
