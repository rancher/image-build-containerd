ARG BCI_IMAGE=registry.suse.com/bci/bci-base
ARG GO_IMAGE=rancher/hardened-build-base:v1.25.8b1
FROM ${BCI_IMAGE} AS bci
FROM ${GO_IMAGE} AS builder
ARG GOOS="linux"
ARG TARGETARCH
# setup required packages
RUN set -x && \
    apk --no-cache add \
    btrfs-progs-dev \
    btrfs-progs-static \
    file \
    gcc \
    git \
    libselinux-dev \
    libseccomp-dev \
    libseccomp-static \
    make \
    mercurial \
    subversion \
    unzip
ARG PROTOC_AARCH64_SHA256="ceb29d4890a31ba871829d22c2b7fa28f237d2b91ce4ea2a53e893d60a1cd502"
ARG PROTOC_X86_64_SHA256="d4246a5136cf9cd1abc851c521a1ad6b8884df4feded8b9cbd5e2a2226d4b357"
RUN if [ "${TARGETARCH}" == "arm64" ]; then \
        curl -LO https://github.com/protocolbuffers/protobuf/releases/download/v3.17.3/protoc-3.17.3-linux-aarch_64.zip; \
        echo "${PROTOC_AARCH64_SHA256}  protoc-3.17.3-linux-aarch_64.zip" | sha256sum -c -; \
        unzip protoc-3.17.3-linux-aarch_64.zip -d /usr; \
    else \
        curl -LO https://github.com/protocolbuffers/protobuf/releases/download/v3.17.3/protoc-3.17.3-linux-x86_64.zip; \
        echo "${PROTOC_X86_64_SHA256}  protoc-3.17.3-linux-x86_64.zip" | sha256sum -c -; \
        unzip protoc-3.17.3-linux-x86_64.zip -d /usr; \
    fi
# setup containerd build
ARG SRC="github.com/k3s-io/containerd"
ARG PKG="github.com/containerd/containerd"
ARG TAG="v2.1.5-k3s1"
RUN git clone --depth=1 https://${SRC}.git $GOPATH/src/${PKG}
WORKDIR $GOPATH/src/${PKG}
RUN git fetch --tags --depth=1 origin ${TAG}
RUN git checkout tags/${TAG} -b ${TAG}
RUN GOPKG=$(grep '^module ' go.mod | awk '{print $2}'); \
    export GO_LDFLAGS="-linkmode=external \
    -X ${GOPKG}/version.Version=${TAG} \
    -X ${GOPKG}/version.Package=${SRC} \
    -X ${GOPKG}/version.Revision=$(git rev-parse HEAD) \
    " && \
    export GO_BUILDTAGS="apparmor,seccomp,selinux,static_build,netgo,osusergo" && \
    export GO_BUILDFLAGS="-gcflags=-trimpath=${GOPATH}/src -tags=${GO_BUILDTAGS}" && \
    go-build-static.sh ${GO_BUILDFLAGS} -o bin/ctr                      ./cmd/ctr && \
    go-build-static.sh ${GO_BUILDFLAGS} -o bin/containerd               ./cmd/containerd && \
    go-build-static.sh ${GO_BUILDFLAGS} -o bin/containerd-stress        ./cmd/containerd-stress && \
    go-build-static.sh ${GO_BUILDFLAGS} -o bin/containerd-shim-runc-v2  ./cmd/containerd-shim-runc-v2
RUN go-assert-static.sh bin/*
RUN if [ "${TARGETARCH}" = "amd64" ]; then \
        go-assert-boring.sh \
        bin/ctr \
        bin/containerd; \
    fi
RUN install -s bin/* /usr/local/bin
RUN containerd --version

FROM bci
COPY --from=builder /usr/local/bin/ /usr/local/bin/
