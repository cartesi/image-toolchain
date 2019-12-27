# Copyright 2019 Cartesi Pte. Ltd.
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

FROM ubuntu:18.04

LABEL maintainer="Diego Nehab <diego@cartesi.io>"

ENV DEBIAN_FRONTEND=noninteractive

ENV BASE "/opt/riscv"

ENV BUILD_BASE "/tmp/build"

RUN \
    mkdir -p $BASE $BUILD_BASE

RUN \
    apt-get update && \
    apt-get install --no-install-recommends -y \
        build-essential autoconf automake libtool libtool-bin autotools-dev \
        git make pkg-config patchutils gawk bison flex ca-certificates \
        device-tree-compiler libmpc-dev libmpfr-dev libgmp-dev rsync cpio \
        libusb-1.0-0-dev texinfo gperf bc zlib1g-dev libncurses-dev genext2fs \
        wget vim wget curl zip unzip libexpat-dev python python3 help2man && \
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
    git checkout -b gcc-9.2 7bd6bb002fe52edcefdb3c02111548237551ac37 && \
    ./bootstrap && \
    ./configure --prefix=/usr/local && \
    make && \
    make install && \
    rm -rf $BUILD_BASE

# Build gcc 9.2 using crosstool-ng
# ----------------------------------------------------
# Add user to run crosstool-ng (it is dangerous to run it as root),
RUN \
    adduser ct-ng --gecos ",,," --disabled-password

RUN \
    mkdir -p $BUILD_BASE/toolchain

COPY ct-ng-config $BUILD_BASE/toolchain/.config

RUN \
    chown -R ct-ng:ct-ng $BUILD_BASE/toolchain && \
    chmod o+w $BUILD_BASE && \
    chmod o+w $BASE

USER ct-ng

RUN \
    cd $BUILD_BASE/toolchain && \
    (ct-ng build.$(nproc) || cat build.log) && \
    rm -rf $BUILD_BASE/toolchain

USER root

# Clean up
# ----------------------------------------------------
RUN \
    rm -rf $BUILD_BASE && \
    unset BUILD_BASE && \
    chmod o-w $BASE && \
    chown -R root:root $BASE && \
    deluser ct-ng --remove-home

ENV PATH="${PATH}:${BASE}/riscv64-unknown-linux-gnu/bin"

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

WORKDIR $BASE

CMD ["/bin/bash", "-l"]
