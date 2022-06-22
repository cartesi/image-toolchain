# Copyright 2019-2022 Cartesi Pte. Ltd.
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

.PHONY: build push clean

TOOLCHAIN_TAG ?= devel
TOOLCHAIN_CONFIG ?= configs/ct-ng-config-default
CONTAINER_BASE := /opt/cartesi/toolchain
KERNEL_VERSION ?= 5.5.19-ctsi-5
KERNEL_SRCPATH := linux-$(KERNEL_VERSION).tar.gz

ifeq ($(fd_emulation),yes)
TOOLCHAIN_CONFIG = configs/ct-ng-config-lp64d
endif

BUILD_ARGS = --build-arg TOOLCHAIN_CONFIG=$(TOOLCHAIN_CONFIG) \
             --build-arg KERNEL_VERSION=$(KERNEL_VERSION)

build: $(KERNEL_SRCPATH)
	docker build -t cartesi/toolchain:${TOOLCHAIN_TAG} $(BUILD_ARGS) .

push:
	docker push cartesi/toolchain:${TOOLCHAIN_TAG}

run:
	docker run --hostname toolchain-env -it --rm \
		-e USER=$$(id -u -n) \
		-e GROUP=$$(id -g -n) \
		-e UID=$$(id -u) \
		-e GID=$$(id -g) \
		-v `pwd`:$(CONTAINER_BASE) \
		-w $(CONTAINER_BASE) \
		cartesi/toolchain:$(TOOLCHAIN_TAG) $(CONTAINER_COMMAND)

run-as-root:
	docker run --hostname toolchain-env -it --rm \
		-v `pwd`:$(CONTAINER_BASE) \
		-w $(CONTAINER_BASE) \
		cartesi/toolchain:$(TOOLCHAIN_TAG) $(CONTAINER_COMMAND)

# fetch the public cartesi linux sources if none was provided
$(KERNEL_SRCPATH):
	wget -O $@ https://github.com/cartesi/linux/archive/v$(KERNEL_VERSION).tar.gz
	echo "4266d1c3d56f79088d9328521bcdb5ad9c385cd9ea8f28457cc61658f43092f4  $@" | shasum -ca 256 || exit 1

clean:
	rm -f $(KERNEL_SRCPATH)
