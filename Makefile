SEVERITIES = HIGH,CRITICAL

.PHONY: all
all:
	docker build --build-arg TAG=$(TAG) -t rancher/containerd:$(TAG) .

.PHONY: image-push
image-push:
	docker push rancher/containerd:$(TAG) >> /dev/null

.PHONY: scan
image-scan:
	trivy --severity $(SEVERITIES) --no-progress --skip-update --ignore-unfixed rancher/containerd:$(TAG)

.PHONY: image-manifest
image-manifest:
	docker image inspect rancher/containerd:$(TAG)
	DOCKER_CLI_EXPERIMENTAL=enabled docker manifest create rancher/containerd:$(TAG) \
		$(shell docker image inspect rancher/containerd:$(TAG) | jq -r '.[] | .RepoDigests[0]')
