ARG GO_IMAGE=rancher/hardened-build-base:v1.26.8b1

# Image that provides cross-compilation tooling.
FROM --platform=$BUILDPLATFORM rancher/mirrored-tonistiigi-xx:1.6.1 AS xx

FROM --platform=$BUILDPLATFORM ${GO_IMAGE} AS builder
# Copy xx scripts to the build stage.
COPY --from=xx / /
ARG GOOS="linux"
ARG TARGETARCH
ARG TARGETPLATFORM
# setup required packages
RUN apk --no-cache add \
    file \
    git \
    make \
    mercurial \
    subversion \
    clang lld \
    unzip
RUN set -x && \
    xx-info env && \
    xx-apk --no-cache add \
    btrfs-progs-dev \
    btrfs-progs-static \
    gcc \
    musl-dev \
    libselinux-dev \
    libseccomp-dev \
    libseccomp-static
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
ARG TAG
RUN git clone --depth=1 https://${SRC}.git $GOPATH/src/${PKG}
WORKDIR $GOPATH/src/${PKG}
RUN git fetch --tags --depth=1 origin ${TAG}
RUN git checkout tags/${TAG} -b ${TAG}
COPY go-mod-overrides ./go-mod-overrides
RUN go-mod-overrides.sh ./go-mod-overrides
RUN GOPKG=$(grep '^module ' go.mod | awk '{print $2}'); \
    xx-go --wrap && \
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
RUN xx-verify --static bin/* && \
    go-assert-static.sh bin/*
RUN if [ "${TARGETARCH}" = "amd64" ]; then \
        go-assert-boring.sh \
        bin/ctr \
        bin/containerd; \
    fi
RUN install bin/* /usr/local/bin

FROM ${GO_IMAGE} AS strip_binary
# strip needs to run on TARGETPLATFORM, not BUILDPLATFORM.
# We are explicit in the binaries we copy because there are dangling clang symlinks in /usr/local/bin that we do not want to include
COPY --from=builder /usr/local/bin/ /usr/local/bin/
RUN strip \
    /usr/local/bin/ctr \
    /usr/local/bin/containerd \
    /usr/local/bin/containerd-stress \
    /usr/local/bin/containerd-shim-runc-v2 && \
    containerd --version

FROM scratch
COPY --from=strip_binary \
    /usr/local/bin/ctr \
    /usr/local/bin/containerd \
    /usr/local/bin/containerd-stress \
    /usr/local/bin/containerd-shim-runc-v2 \
    /usr/local/bin/
