ARG UBI_IMAGE=registry.access.redhat.com/ubi7/ubi-minimal:latest
ARG GO_IMAGE=briandowns/rancher-build-base:v0.1.0

FROM ${UBI_IMAGE} as ubi

FROM ${GO_IMAGE} as builder
ARG TAG="" 
RUN apt update     && \ 
    apt upgrade -y && \ 
    apt install -y ca-certificates git \
                   wget unzip btrfs-tools libseccomp-dev
RUN wget -c https://github.com/google/protobuf/releases/download/v${TAG}/protoc-${TAG}-linux-x86_64.zip && \
    unzip protoc-${TAG}-linux-x86_64.zip -d /usr/local
RUN go get github.com/containerd/containerd         && \
    go get github.com/opencontainers/runc           && \
    cd $GOPATH/src/github.com/opencontainers/runc   && \
    make static                                     && \
    make install                                    && \
    cd $GOPATH/src/github.com/containerd/containerd && \
    make                                            && \
    make install

FROM ubi
RUN microdnf update -y && \ 
	rm -rf /var/cache/yum

COPY --from=builder /go/src/github.com/containerd/containerd/bin /usr/local/bin
COPY --from=builder /go/src/github.com/opencontainers/runc/runc /usr/local/bin
