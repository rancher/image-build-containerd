SEVERITIES = HIGH,CRITICAL

.PHONY: all
all:
	docker build --build-arg TAG=$(TAG) -t ranchertest/containerd:$(TAG) .

.PHONY: image-push
image-push:
	docker push ranchertest/containerd:$(V_TAG) >> /dev/null

.PHONY: scan
image-scan:
	trivy --severity $(SEVERITIES) --no-progress --skip-update --ignore-unfixed ranchertest/containerd:$(TAG)

.PHONY: image-manifest
image-manifest:
	docker image inspect ranchertest/containerd:$(TAG)
	DOCKER_CLI_EXPERIMENTAL=enabled docker manifest create ranchertest/containerd:$(TAG) \
		$(shell docker image inspect ranchertest/containerd:$(TAG) | jq -r '.[] | .RepoDigests[0]')
