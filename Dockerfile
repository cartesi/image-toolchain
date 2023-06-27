# Copyright 2019-2023 Cartesi Pte. Ltd.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not
# use this file except in compliance with the License. You may obtain a copy of
# the License at http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations under
# the License.
#

FROM debian:bookworm-20230612 as ct-ng-builder

LABEL maintainer="Machine Reference Unit <https://discord.com/channels/600597137524391947/1107965671976992878>"

ARG KERNEL_VERSION # define on makefile or CI
ARG TOOLCHAIN_CONFIG=configs/ct-ng-config-default

ENV DEBIAN_FRONTEND=noninteractive

ENV BASE "/opt/riscv"

ENV BUILD_BASE "/tmp/build"

RUN \
    mkdir -p $BASE $BUILD_BASE

RUN \
    apt-get update && \
    apt-get install --no-install-recommends -y \
        build-essential autoconf automake libtool libtool-bin autotools-dev \
        git make pkg-config patchutils gawk bison flex ca-certificates gnupg \
        device-tree-compiler libmpc-dev libmpfr-dev libgmp-dev rsync cpio \
        libusb-1.0-0-dev texinfo gperf bc zlib1g-dev libncurses-dev genext2fs \
        wget vim wget curl zip unzip libexpat-dev python3 help2man && \
    rm -rf /var/lib/apt/lists/*


# Install workaround to run as current user
# ----------------------------------------------------
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

RUN \
    chmod +x /usr/local/bin/entrypoint.sh

RUN \
    cd $BUILD_BASE && \
    git clone --branch v0.2 --depth 1 https://github.com/ncopa/su-exec.git && \
    cd su-exec && \
    if [ `git rev-parse --verify HEAD` != 'f85e5bde1afef399021fbc2a99c837cf851ceafa' ]; then exit 1; fi && \
    make && \
    cp su-exec /usr/local/bin/

# Download and install crosstool-ng
# ----------------------------------------------------
RUN \
    cd $BUILD_BASE && \
    git clone https://github.com/crosstool-ng/crosstool-ng && \
    cd crosstool-ng && \
    git checkout -b custom_version dd20ee5526b08baf97ca559e93d7546ec0746cfa && \
    ./bootstrap && \
    ./configure --prefix=/usr/local && \
    make && \
    make install && \
    rm -rf $BUILD_BASE

FROM ct-ng-builder as toolchain-builder
# Build gcc using crosstool-ng
# ----------------------------------------------------
# Add user to run crosstool-ng (it is dangerous to run it as root),
RUN \
    adduser developer -u 499 --gecos ",,," --disabled-password

RUN \
    mkdir -p $BUILD_BASE/toolchain

COPY $TOOLCHAIN_CONFIG $BUILD_BASE/toolchain/.config

RUN \
    chown -R developer:developer $BUILD_BASE/toolchain && \
    chmod o+w $BUILD_BASE && \
    chmod o+w $BASE

USER developer

COPY linux-$KERNEL_VERSION.tar.gz $BUILD_BASE/linux-$KERNEL_VERSION.tar.gz
RUN \
    cd $BUILD_BASE/toolchain && \
    (ct-ng build.$(nproc) || (cat build.log && exit 1)) && \
    rm -rf $BUILD_BASE/toolchain $BUILD_BASE/linux-$KERNEL_VERSION.tar.gz

USER root

FROM toolchain-builder as rust-builder
# Install Rust tools
# ----------------------------------------------------

# Get Rust
ENV CARGO_HOME=/opt/.cargo/
ENV RUSTUP_HOME=/opt/.rustup/
ENV PATH="/opt/.cargo/bin:${PATH}"

RUN \
    wget https://github.com/rust-lang/rustup/archive/refs/tags/1.25.2.tar.gz && \
    echo "dc9bb5d3dbac5cea9afa9b9c3c96fcf644a1e7ed6188a6b419dfe3605223b5f3  1.25.2.tar.gz" | sha256sum --check && \
    tar xf 1.25.2.tar.gz && \
    bash rustup-1.25.2/rustup-init.sh \
        -y \
        --default-toolchain 1.70.0 \
        --profile minimal \
        --target riscv64gc-unknown-linux-gnu && \
    mkdir -p /opt/.cargo/registry && \
    chmod -R o+w /opt/.cargo/registry && \
    chmod -R o+w /opt/.rustup/settings.toml && \
    echo "[target.riscv64gc-unknown-linux-gnu]\nlinker = \"riscv64-cartesi-linux-gnu-gcc\"" >> /opt/.cargo/config.toml && \
    rm -rf 1.25.2.tar.gz rustup-1.25.2

# Clean up
# ----------------------------------------------------
RUN \
    rm -rf $BUILD_BASE && \
    unset BUILD_BASE && \
    chmod o-w $BASE && \
    chown -R root:root $BASE

ENV PATH="${PATH}:${BASE}/riscv64-cartesi-linux-gnu/bin"

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

WORKDIR $BASE

CMD ["/bin/bash", "-l"]
