FROM ubuntu:18.04

MAINTAINER Diego Nehab <diego.nehab@gmail.com>

ENV DEBIAN_FRONTEND=noninteractive

ENV OLDPATH=$PATH

ENV BASE "/opt/riscv"

RUN \
    mkdir -p $BASE

# Ideally, we should be able to compile a single version of
# gcc with --enable-multilib that would support
# ABI lp64d and ISA rv64imafd, as well as ABI lp64 and ISA rv64ima
# We need to compile the kernel and bbl with ABI lp64 and ISA
# rv64ima so bbl can emulate the floating-point
# instructions. The rest we can compile however we like, but
# should prefer ABI lp64d and ISA rv64imafd so that, in the
# future, we can use native floating-point.
# Unfortunately, buildroot gets confused with the sysroot
# layout of riscv's multilib and fails. So instead we
# compile two independent gcc.
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
    git clone --branch cartesi --depth 1 \
        https://github.com/cartesi/riscv-gnu-toolchain.git && \
    cd riscv-gnu-toolchain && \
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
    NPROC=$(nproc) && \
    ARCH=rv64imafd && \
    ABI=lp64d && \
    RISCV="$BASE/linux/$ARCH-$ABI" && \
    mkdir -p $RISCV && \
    ./configure --prefix=$RISCV --with-arch=$ARCH --with-abi=$ABI && \
    make clean && \
    make -j$NPROC linux && \
    ARCH=rv64ima && \
    ABI=lp64 && \
    RISCV="$BASE/linux/$ARCH-$ABI" && \
    mkdir -p $RISCV && \
    ./configure --prefix=$RISCV --with-arch=$ARCH --with-abi=$ABI && \
    make clean && \
    make -j$NPROC linux && \
    ARCH=rv64imafd && \
    ABI=lp64d && \
    RISCV="$BASE/elf/$ARCH-$ABI" && \
    mkdir -p $RISCV && \
    ./configure --prefix=$RISCV --with-arch=$ARCH --with-abi=$ABI && \
    make clean && \
    make -j$NPROC && \
    ARCH=rv64ima && \
    ABI=lp64 && \
    RISCV="$BASE/elf/$ARCH-$ABI" && \
    mkdir -p $RISCV && \
    ./configure --prefix=$RISCV --with-arch=$ARCH --with-abi=$ABI && \
    make clean && \
    make -j$NPROC && \
    cd .. && \
    \rm -rf riscv-gnu-toolchain

USER root

WORKDIR $BASE

CMD ["/bin/bash", "-l"]
