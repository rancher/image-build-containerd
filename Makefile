SEVERITIES = HIGH,CRITICAL

.PHONY: all
all:
	docker build --build-arg TAG=$(TAG) -t rancher/hardened-containerd:$(TAG) .

.PHONY: image-push
image-push:
	docker push rancher/hardened-containerd:$(TAG) >> /dev/null

.PHONY: scan
image-scan:
	trivy --severity $(SEVERITIES) --no-progress --skip-update --ignore-unfixed rancher/hardened-containerd:$(TAG)

.PHONY: image-manifest
image-manifest:
	docker image inspect rancher/hardened-containerd:$(TAG)
	DOCKER_CLI_EXPERIMENTAL=enabled docker manifest create rancher/hardened-containerd:$(TAG) \
		$(shell docker image inspect rancher/hardened-containerd:$(TAG) | jq -r '.[] | .RepoDigests[0]')
