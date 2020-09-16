ARG UBI_IMAGE=registry.access.redhat.com/ubi7/ubi-minimal:latest
ARG GO_IMAGE=rancher/hardened-build-base:v1.14.2-amd64

FROM ${UBI_IMAGE} as ubi

FROM ${GO_IMAGE} as builder
ARG TAG=""
RUN apt update                                        && \
    apt upgrade -y                                    && \
    apt install -y ca-certificates git wget libbtrfs-dev \
    unzip btrfs-tools libseccomp-dev libselinux-dev zlib1g-dev

RUN wget -c https://github.com/google/protobuf/releases/download/v3.11.4/protoc-3.11.4-linux-x86_64.zip && \
    unzip protoc-3.11.4-linux-x86_64.zip -d /usr/local && ldconfig
RUN git clone --depth=1 https://github.com/rancher/containerd.git $GOPATH/src/github.com/containerd/containerd && \
    cd $GOPATH/src/github.com/containerd/containerd                                                            && \
    git fetch --all --tags --prune                                                                             && \
    git checkout tags/${TAG} -b ${TAG}                                                                         && \
    make PACKAGE=github.com/rancher/containerd VERSION=${TAG} EXTRA_LDFLAGS='-extldflags=-static' BUILDTAGS='apparmor seccomp selinux'             && \
    make install

FROM ubi
RUN microdnf update -y && \
    rm -rf /var/cache/yum

COPY --from=builder /go/src/github.com/containerd/containerd/bin /usr/local/bin
