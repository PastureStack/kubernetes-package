TARGETS := $(shell ls scripts)

DAPPER_IMAGE ?= pasturestack-kubernetes-package-dapper:go1.26.5-docker29.6.2-ubuntu26
DAPPER_HOST_ARCH ?= amd64
GO_VERSION ?= 1.26.5
GO_LINUX_AMD64_SHA256 ?= 5c2c3b16caefa1d968a94c1daca04a7ca301a496d9b086e17ad77bb81393f053
DOCKER_VERSION ?= 29.6.2
DOCKER_LINUX_AMD64_SHA256 ?= d6204aea92238e2453d5445c885b9d2e5eb8f82915568ec50edf9dbe12a3ac74
UBUNTU_MIRROR ?= https://archive.ubuntu.com/ubuntu

.PHONY: $(TARGETS) dapper-image

dapper-image:
	docker build \
		$(if $(DOCKER_BUILD_NETWORK),--network $(DOCKER_BUILD_NETWORK),) \
		--build-arg DAPPER_HOST_ARCH=$(DAPPER_HOST_ARCH) \
		--build-arg GO_VERSION=$(GO_VERSION) \
		--build-arg GO_LINUX_AMD64_SHA256=$(GO_LINUX_AMD64_SHA256) \
		--build-arg DOCKER_VERSION=$(DOCKER_VERSION) \
		--build-arg DOCKER_LINUX_AMD64_SHA256=$(DOCKER_LINUX_AMD64_SHA256) \
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
