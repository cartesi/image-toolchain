# Cartesi Machine Image Toolchain

The Cartesi Image Toolchain is the repository that provides the Docker configuration files to build a image containing the RISC-V toolchain. This image is used to compile software for the Cartesi Machine Emulator reference implementation. The current toolchain is based on Ubuntu 22.04 and GNU GCC 9.3.0. The target architecture is RISC-V RV64IMA with ABI LP64.

## Getting Started

### Requirements

- Docker 18.x
- GNU Make >= 3.81

### Build

```bash
$ make build
```

If you want to tag the image with custom name you can do the following:

```bash
$ make build TOOLCHAIN_TAG=mytag
```

If you want to remove the temporary downloaded files for a clean build:

```bash
$ make clean
```

To remove the generated images from your system, please refer to the Docker documentation.

#### Makefile targets

The following options are available as `make` targets:

- **build**: builds the RISC-V gnu toolchain docker image
- **run**: runs the generated image with current user UID and GID
- **run-as-root**: runs the generated image as root
- **push**: pushes the image to the registry repository
- **clean**: cleans temporary downloaded files

#### Makefile container options

You can pass the following variables to the make target if you wish to use different docker image tags.

- TOOLCHAIN\_TAG: toolchain image tag

```
$ make build TOOLCHAIN_TAG=mytag
```

It's also useful if you want to use pre-built images:

```
$ make run TOOLCHAIN_TAG=latest
```

## Usage

```
$ make run
```

- KERNEL\_VERSION: kernel version that the toolchain headers will be based upon.

### Customize toolchain headers

You can select different kernel versions to extract the headers from.
To do this download the linux source code and move it into the file: `linux-$(KERNEL_VERSION).tar.gz`.

Then call make with KERNEL\_VERSION specified

```
make KERNEL_VERSION=5.15.63-ctsi-2
```

## Contributing

Thank you for your interest in Cartesi! Head over to our [Contributing Guidelines](CONTRIBUTING.md) for instructions on how to sign our Contributors Agreement and get started with Cartesi!

Please note we have a [Code of Conduct](CODE_OF_CONDUCT.md), please follow it in all your interactions with the project.

## License

The image-toolchain repository and all contributions are licensed under
[APACHE 2.0](https://www.apache.org/licenses/LICENSE-2.0). Please review our [LICENSE](LICENSE) file.
