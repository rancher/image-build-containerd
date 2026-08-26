# rancher/hardened-containerd

This repository builds a hardened containerd image for use with rke2. Binaries are placed inside a scratch image for the explicit purpose of presenting an image to extract the binaries from, and not for running containerd inside a container.

## Build

```sh
TAG=v1.3.6-k3s2 make
```

## Automation 

This repository uses [updatecli](https://updatecli.io/) to automate the build base version bumping. Unlike other image-build-XXXX repositories, this repository continues to use the sync-upstream approach to bump the TAG, as the k3s-io org controls the containerd repository, and multiple TAG channels are used. 