FROM ubuntu:18.04

MAINTAINER Diego Nehab <diego.nehab@gmail.com>

ENV DEBIAN_FRONTEND=noninteractive

ENV OLDPATH=$PATH

ENV BASE "/opt/riscv"

RUN \
    mkdir -p $BASE

# Ideally, we should be able to compile a single version of
# gcc with --enable-multilib that would support ABI lp64d
# and ISA rv64imafd, as well as ABI lp64 and ISA rv64ima
# We need to compile the kernel and bbl with ABI lp64 and
# ISA rv64ima so bbl can emulate the floating-point
# instructions.
# The rest we can compile however we like.
# We should prefer ABI lp64d and ISA rv64imafd if we want to
# support an emulator that understands floating-point instructions.
# We should prefer ABI lp64 and ISA rv64ima if we want the
# best performance without native floating-point support.


# Unfortunately, buildroot gets confused with the sysroot
# layout of riscv's multilib and fails. So instead we
# compile two independent gccs.
# ----------------------------------------------------

RUN \
    apt-get update && \
    apt-get install --no-install-recommends -y \
        build-essential autoconf automake libtool autotools-dev \
        git make pkg-config patchutils gawk bison flex ca-certificates \
        device-tree-compiler libmpc-dev libmpfr-dev libgmp-dev \
        libusb-1.0-0-dev texinfo gperf bc zlib1g-dev libncurses-dev \
        wget vim wget curl zip unzip libexpat-dev python && \
    rm -rf /var/lib/apt/lists/*

# Download sources and build compilers
# ----------------------------------------------------
RUN \
    mkdir -p $BASE/src && \
    cd $BASE/src && \
    git clone --branch cartesi --depth 1 \
        https://github.com/cartesi/riscv-gnu-toolchain.git && \
    cd $BASE/src/riscv-gnu-toolchain && \
        git clone --branch cartesi --depth 1 \
            https://github.com/cartesi/riscv-gcc.git && \
        git clone --branch cartesi --depth 1 \
            https://github.com/cartesi/riscv-qemu.git && \
        git clone --branch cartesi --depth 1 \
            https://github.com/cartesi/riscv-binutils-gdb.git && \
        git clone --branch cartesi --depth 1 \
            https://github.com/cartesi/riscv-glibc.git && \
        git clone --branch cartesi --depth 1 \
            https://github.com/cartesi/riscv-newlib.git && \
        git clone --branch cartesi --depth 1 \
            https://github.com/cartesi/riscv-dejagnu.git && \
    cd $BASE/src && \
    git clone --branch cartesi --depth 1 \
        https://github.com/cartesi/riscv-linux.git && \
    cd $BASE/src/riscv-linux && \
    make ARCH=riscv \
        INSTALL_HDR_PATH=$BASE/src/riscv-gnu-toolchain/linux-headers \
        headers_install && \
    cd $BASE/src/riscv-gnu-toolchain && \
    NPROC=$(nproc) && \
    ARCH=rv64imafd && \
    ABI=lp64d && \
    RISCV="$BASE/toolchain/linux/$ARCH-$ABI" && \
    mkdir -p $RISCV && \
    ./configure --prefix=$RISCV --with-arch=$ARCH --with-abi=$ABI && \
    make clean && \
    make -j$NPROC linux && \
    sed 's/^#define LINUX_VERSION_CODE.*/#define LINUX_VERSION_CODE 263682/' \
        -i $RISCV/sysroot/usr/include/linux/version.h && \
    ARCH=rv64ima && \
    ABI=lp64 && \
    RISCV="$BASE/toolchain/linux/$ARCH-$ABI" && \
    mkdir -p $RISCV && \
    ./configure --prefix=$RISCV --with-arch=$ARCH --with-abi=$ABI && \
    make clean && \
    make -j$NPROC linux && \
    sed 's/^#define LINUX_VERSION_CODE.*/#define LINUX_VERSION_CODE 263682/' \
        -i $RISCV/sysroot/usr/include/linux/version.h && \
    ARCH=rv64imafd && \
    ABI=lp64d && \
    RISCV="$BASE/toolchain/elf/$ARCH-$ABI" && \
    mkdir -p $RISCV && \
    ./configure --prefix=$RISCV --with-arch=$ARCH --with-abi=$ABI && \
    make clean && \
    make -j$NPROC && \
    ARCH=rv64ima && \
    ABI=lp64 && \
    RISCV="$BASE/toolchain/elf/$ARCH-$ABI" && \
    mkdir -p $RISCV && \
    ./configure --prefix=$RISCV --with-arch=$ARCH --with-abi=$ABI && \
    make clean && \
    make -j$NPROC && \
    cd $BASE && \
    \rm -rf $BASE/src

USER root

WORKDIR $BASE

CMD ["/bin/bash", "-l"]
