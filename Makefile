SEVERITIES = HIGH,CRITICAL

UNAME_M = $(shell uname -m)
ifndef TARGET_PLATFORMS
	ifeq ($(UNAME_M), x86_64)
		TARGET_PLATFORMS:=linux/amd64
	else ifeq ($(UNAME_M), aarch64)
		TARGET_PLATFORMS:=linux/arm64
	else 
		TARGET_PLATFORMS:=linux/$(UNAME_M)
	endif
endif

ifeq ($(OS),)
	OS=$(shell go env GOOS)
endif

ifeq ($(OS),windows)
	DOCKERFILE=Dockerfile.windows
else
	DOCKERFILE=Dockerfile
endif

BUILD_META=-build$(shell TZ=UTC date +%Y%m%d)
ORG ?= rancher
TAG ?= v2.2.7-k3s1$(BUILD_META)

ifneq (${GITHUB_ACTION_TAG},)
	TAG = ${GITHUB_ACTION_TAG}
endif

ifeq (,$(filter %$(BUILD_META),$(TAG)))
	$(error TAG needs to end with build metadata)
endif

.PHONY: image-build
image-build:
	docker buildx build \
		--pull \
		--load \
		--build-arg TAG=$(TAG:$(BUILD_META)=) \
		--platform=$(TARGET_PLATFORMS) \
		--build-arg GOOS=$(OS) \
		--tag $(ORG)/hardened-containerd:$(TAG) \
		--file $(DOCKERFILE) \
		.

.PHONY: image-push
image-push:
	docker push $(ORG)/hardened-containerd:$(TAG)

.PHONY: image-manifest
image-manifest:
	DOCKER_CLI_EXPERIMENTAL=enabled docker manifest create --amend \
		$(ORG)/hardened-containerd:$(TAG)
	DOCKER_CLI_EXPERIMENTAL=enabled docker manifest push \
		$(ORG)/hardened-containerd:$(TAG)

.PHONY: image-scan
image-scan:
	trivy image --severity $(SEVERITIES) --no-progress --ignore-unfixed $(ORG)/hardened-containerd:$(TAG)

.PHONY: log
log:
	@echo "TARGET_PLATFORMS=$(TARGET_PLATFORMS)"
	@echo "TAG=$(TAG:$(BUILD_META)=)"
	@echo "ORG=$(ORG)"
	@echo "BUILD_META=$(BUILD_META)"
	@echo "K3S_ROOT_VERSION=$(K3S_ROOT_VERSION)"
	@echo "UNAME_M=$(UNAME_M)"
