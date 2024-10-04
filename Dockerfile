# Copyright Cartesi and individual authors (see AUTHORS)
# SPDX-License-Identifier: Apache-2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

FROM debian:bookworm-20240926 as ct-ng-builder

LABEL maintainer="Machine Reference Unit <https://discord.com/channels/600597137524391947/1107965671976992878>"

ARG KERNEL_VERSION # define on makefile or CI
ARG TOOLCHAIN_CONFIG=configs/ct-ng-config
ARG TARGETARCH

ENV DEBIAN_FRONTEND=noninteractive

ENV BASE "/opt/riscv"

ENV BUILD_BASE "/tmp/build"

RUN \
    apt-get update && \
    apt-get install --no-install-recommends -y \
        build-essential autoconf automake libtool libtool-bin autotools-dev \
        git make pkg-config patchutils gawk bison flex ca-certificates gnupg \
        device-tree-compiler libmpc-dev libmpfr-dev libgmp-dev rsync cpio \
        libusb-1.0-0-dev texinfo gperf bc zlib1g-dev libncurses-dev \
        wget vim wget curl zip unzip libexpat-dev python3 help2man && \
    rm -rf /var/lib/apt/lists/*

RUN \
    wget -O /tmp/xgenext2fs.deb https://github.com/cartesi/genext2fs/releases/download/v1.5.6/xgenext2fs_${TARGETARCH}.deb && \
    case ${TARGETARCH} in \
      amd64) echo "996e4e68a638b5dc5967d3410f92ecb8d2f41e32218bbe0f8b4c4474d7eebc59  /tmp/xgenext2fs.deb" | sha256sum --check ;; \
      arm64) echo "e5aca81164b762bbe5447bacef41e4fa9e357fd9c8f44e519c5206227d43144d  /tmp/xgenext2fs.deb" | sha256sum --check ;; \
    esac && \
    apt-get update && \
    apt-get install --no-install-recommends -y \
      /tmp/xgenext2fs.deb && \
    rm -rf /var/lib/apt/lists/*

RUN \
    adduser developer -u 499 --gecos ",,," --disabled-password && \
    mkdir -m 775 -p $BASE $BUILD_BASE && \
    chown -R root:developer $BASE $BUILD_BASE

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
    cp su-exec /usr/local/bin/ && \
    rm -rf $BUILD_BASE/su-exec


# Download and install crosstool-ng
# ----------------------------------------------------
RUN \
    cd $BUILD_BASE && \
    git clone https://github.com/crosstool-ng/crosstool-ng && \
    cd crosstool-ng && \
    git checkout -b custom_version 334f6d6479096b20e80fd39e35f404319bc251b5 && \
    ./bootstrap && \
    ./configure --prefix=/usr/local && \
    make && \
    make install && \
    rm -rf $BUILD_BASE/crosstool-ng

# Build gcc using crosstool-ng
# ----------------------------------------------------
FROM ct-ng-builder as toolchain-builder

COPY $TOOLCHAIN_CONFIG $BUILD_BASE/ct-ng-config

# Change user to run crosstool-ng (it is dangerous to run it as root)
USER developer

COPY linux-$KERNEL_VERSION.tar.gz $BUILD_BASE/linux-$KERNEL_VERSION.tar.gz
RUN \
    mkdir -p $BUILD_BASE/gcc && \
    cd $BUILD_BASE/gcc && \
    cp $BUILD_BASE/ct-ng-config .config && \
    (ct-ng build.$(nproc) || (cat build.log && exit 1)) && \
    rm -rf $BUILD_BASE/gcc $BUILD_BASE/linux-$KERNEL_VERSION.tar.gz

USER root

ENV PATH="${BASE}/riscv64-cartesi-linux-gnu/bin/:${PATH}"

# On Debian bash -l overwrites the PATH variable, so we need to set it again
RUN \
    echo "export PATH=\"${BASE}/riscv64-cartesi-linux-gnu/bin:\$PATH\"" >> /etc/profile.d/riscv64-cartesi-linux-gnu.sh && \
    chown -R root:root $BASE/riscv64-cartesi-linux-gnu

# Install Rust tools
# ----------------------------------------------------
FROM toolchain-builder as rust-builder

# Get Rust
ENV CARGO_HOME=$BASE/rust/cargo
ENV RUSTUP_HOME=$BASE/rust/rustup

USER developer
RUN \
    mkdir -p $BUILD_BASE/rust && \
    cd $BUILD_BASE/rust && \
    wget https://github.com/rust-lang/rustup/archive/refs/tags/1.27.0.tar.gz && \
    echo "3d331ab97d75b03a1cc2b36b2f26cd0a16d681b79677512603f2262991950ad1  1.27.0.tar.gz" | sha256sum --check && \
    tar xf 1.27.0.tar.gz && \
    export CARGO_HOME=$BASE/rust/cargo/ && \
    bash rustup-1.27.0/rustup-init.sh \
        -y \
        --default-toolchain 1.77.2 \
        --profile minimal \
        --target riscv64gc-unknown-linux-gnu && \
    echo "[target.riscv64gc-unknown-linux-gnu]\nlinker = \"riscv64-cartesi-linux-gnu-gcc\"" >> $CARGO_HOME/config.toml && \
    mkdir -p $CARGO_HOME/registry && \
    chmod -R o+w $CARGO_HOME/registry && \
    chmod o+w $RUSTUP_HOME/settings.toml && \
    rm -rf $BUILD_BASE/rust

USER root

ENV PATH="${CARGO_HOME}/bin:${PATH}"

# On Debian bash -l overwrites the PATH variable, so we need to set it again
RUN \
    echo "export PATH=\"${CARGO_HOME}/bin:\$PATH\"" >> /etc/profile.d/riscv64gc-rust.sh

FROM rust-builder as toolchain

# Clean up
RUN \
    chown root:root $BASE && \
    rm -rf $BUILD_BASE

WORKDIR $BASE

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

CMD ["/bin/bash", "-l"]
