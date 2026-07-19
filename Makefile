TARGETS := $(shell ls scripts)

DAPPER_IMAGE ?= pasturestack-kubernetes-package-dapper:ubuntu26
DAPPER_HOST_ARCH ?= amd64
DOCKER_VERSION ?= 29.5.3
UBUNTU_MIRROR ?= http://archive.ubuntu.com/ubuntu

.PHONY: $(TARGETS) dapper-image

dapper-image:
	docker build \
		$(if $(DOCKER_BUILD_NETWORK),--network $(DOCKER_BUILD_NETWORK),) \
		--build-arg DAPPER_HOST_ARCH=$(DAPPER_HOST_ARCH) \
		--build-arg DOCKER_VERSION=$(DOCKER_VERSION) \
		--build-arg UBUNTU_MIRROR=$(UBUNTU_MIRROR) \
		-t $(DAPPER_IMAGE) \
		-f Dockerfile.dapper .

$(TARGETS): dapper-image
	docker run --rm \
		-v $(CURDIR):/source \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-e DAPPER_UID=$$(id -u) \
		-e DAPPER_GID=$$(id -g) \
		-e ARCH=$(DAPPER_HOST_ARCH) \
		-e IMAGE_NAME \
		-e IMAGE \
		-e TAG \
		-e KUBERNETES_BINARY_VERSION \
		-e DOCKER_BUILD_NETWORK \
		-e UBUNTU_MIRROR=$(UBUNTU_MIRROR) \
		$(DAPPER_IMAGE) $@

.DEFAULT_GOAL := ci
