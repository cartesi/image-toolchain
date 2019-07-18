.PHONY: build push

TOOLCHAIN_TAG ?= latest
CONTAINER_BASE := /opt/cartesi/image-toolchain

build:
	docker build -t cartesi/image-toolchain:${TOOLCHAIN_TAG} .

push:
	docker push cartesi/image-toolchain:${TOOLCHAIN_TAG}

run:
	docker run --hostname toolchain-env -it --rm \
		-e USER=$$(id -u -n) \
		-e GROUP=$$(id -g -n) \
		-e UID=$$(id -u) \
		-e GID=$$(id -g) \
		-v `pwd`:$(CONTAINER_BASE) \
		-w $(CONTAINER_BASE) \
		cartesi/image-toolchain:$(TOOLCHAIN_TAG) $(CONTAINER_COMMAND)

run-as-root:
	docker run --hostname toolchain-env -it --rm \
		cartesi/image-toolchain:$(TOOLCHAIN_TAG) $(CONTAINER_COMMAND)
