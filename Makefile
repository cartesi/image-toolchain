.PHONY: build push

build:
	docker build -t cartesi/image-toolchain:latest .

push:
	docker push cartesi/image-toolchain:latest

run:
	docker run -it --rm cartesi/image-toolchain:latest
