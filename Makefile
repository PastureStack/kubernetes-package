TARGETS := $(shell ls scripts)

DAPPER_IMAGE ?= pasturestack-kubernetes-package-dapper:go1.26.6-docker29.7.2-ubuntu26
DAPPER_HOST_ARCH ?= amd64
GO_VERSION ?= 1.26.6
GO_LINUX_AMD64_SHA256 ?= 708effb774be8237570d0add163225abbdfaf4fca28b2611df167beba4feef89
DOCKER_VERSION ?= 29.7.2
DOCKER_LINUX_AMD64_SHA256 ?= 803d433f226db4776e1768fd319fc6c6e4935a456acf84fcc0080818b854bc8f

.PHONY: $(TARGETS) dapper-image

dapper-image:
	docker build \
		$(if $(DOCKER_BUILD_NETWORK),--network $(DOCKER_BUILD_NETWORK),) \
		--build-arg DAPPER_HOST_ARCH=$(DAPPER_HOST_ARCH) \
		--build-arg GO_VERSION=$(GO_VERSION) \
		--build-arg GO_LINUX_AMD64_SHA256=$(GO_LINUX_AMD64_SHA256) \
		--build-arg DOCKER_VERSION=$(DOCKER_VERSION) \
		--build-arg DOCKER_LINUX_AMD64_SHA256=$(DOCKER_LINUX_AMD64_SHA256) \
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
		$(DAPPER_IMAGE) $@

.DEFAULT_GOAL := ci
