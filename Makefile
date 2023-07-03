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

.PHONY: build push download clean checksum

TOOLCHAIN_SUFFIX ?=
TOOLCHAIN_TAG ?= devel$(TOOLCHAIN_SUFFIX)
TOOLCHAIN_CONFIG ?= configs/ct-ng-config$(TOOLCHAIN_SUFFIX)
CONTAINER_BASE := /opt/cartesi/toolchain$(TOOLCHAIN_SUFFIX)
KERNEL_VERSION ?= 5.15.63-ctsi-2
KERNEL_SRCPATH := linux-$(KERNEL_VERSION).tar.gz

BUILD_ARGS = --build-arg TOOLCHAIN_CONFIG=$(TOOLCHAIN_CONFIG) \
             --build-arg KERNEL_VERSION=$(KERNEL_VERSION)

build: checksum
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
	@wget -O $@ https://github.com/cartesi/linux/archive/v$(KERNEL_VERSION).tar.gz

shasumfile: $(KERNEL_SRCPATH)
	@shasum -a 256 $^ > $@

checksum: $(KERNEL_SRCPATH)
	@shasum -ca 256 shasumfile

download: checksum

clean:
	rm -f $(KERNEL_SRCPATH)
