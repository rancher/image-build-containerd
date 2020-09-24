SEVERITIES = HIGH,CRITICAL

ifeq ($(ARCH),)
ARCH=$(shell go env GOARCH)
endif

ORG ?= rancher
PKG ?= github.com/containerd/containerd
SRC ?= github.com/rancher/containerd
TAG ?= v1.3.6-k3s2

ifneq ($(DRONE_TAG),)
TAG := $(DRONE_TAG)
endif

.PHONY: image-build
image-build:
	docker build \
		--build-arg PKG=$(PKG) \
		--build-arg SRC=$(SRC) \
		--build-arg TAG=$(TAG) \
		--tag $(ORG)/hardened-containerd:$(TAG) \
		--tag $(ORG)/hardened-containerd:$(TAG)-$(ARCH) \
	.

.PHONY: image-push
image-push:
	docker push $(ORG)/hardened-containerd:$(TAG)-$(ARCH)

.PHONY: image-manifest
image-manifest:
	DOCKER_CLI_EXPERIMENTAL=enabled docker manifest create --amend \
		$(ORG)/hardened-containerd:$(TAG) \
		$(ORG)/hardened-containerd:$(TAG)-$(ARCH)
	DOCKER_CLI_EXPERIMENTAL=enabled docker manifest push \
		$(ORG)/hardened-containerd:$(TAG)

.PHONY: image-scan
image-scan:
	trivy --severity $(SEVERITIES) --no-progress --ignore-unfixed $(ORG)/hardened-containerd:$(TAG)
