ARG UBI_IMAGE=registry.access.redhat.com/ubi7/ubi-minimal:latest
ARG GO_IMAGE=rancher/hardened-build-base:v1.16.7b7
FROM ${UBI_IMAGE} as ubi
FROM ${GO_IMAGE} as builder
# setup required packages
RUN set -x \
 && apk --no-cache add \
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
ADD https://github.com/google/protobuf/releases/download/v3.17.3/protoc-3.17.3-linux-x86_64.zip .
RUN unzip protoc-3.17.3-linux-x86_64.zip -d /usr
# setup containerd build
ARG SRC="github.com/k3s-io/containerd"
ARG PKG="github.com/containerd/containerd"
ARG TAG="v1.4.9-k3s1"
RUN git clone --depth=1 https://${SRC}.git $GOPATH/src/${PKG}
WORKDIR $GOPATH/src/${PKG}
RUN git fetch --all --tags --prune
RUN git checkout tags/${TAG} -b ${TAG}
ENV GO_BUILDTAGS="apparmor,seccomp,selinux,static_build,netgo,osusergo"
ENV GO_BUILDFLAGS="-gcflags=-trimpath=${GOPATH}/src -tags=${GO_BUILDTAGS}"
RUN go mod edit --replace google.golang.org/grpc=google.golang.org/grpc@v1.27.1 && go mod tidy
RUN export GO_LDFLAGS="-linkmode=external \
    -X ${PKG}/version.Version=${TAG} \
    -X ${PKG}/version.Package=${SRC} \
    -X ${PKG}/version.Revision=$(git rev-parse HEAD) \
    " \
 && go-build-static.sh ${GO_BUILDFLAGS} -o bin/ctr                      ./cmd/ctr \
 && go-build-static.sh ${GO_BUILDFLAGS} -o bin/containerd               ./cmd/containerd \
 && go-build-static.sh ${GO_BUILDFLAGS} -o bin/containerd-stress        ./cmd/containerd-stress \
 && go-build-static.sh ${GO_BUILDFLAGS} -o bin/containerd-shim          ./cmd/containerd-shim \
 && go-build-static.sh ${GO_BUILDFLAGS} -o bin/containerd-shim-runc-v1  ./cmd/containerd-shim-runc-v1 \
 && go-build-static.sh ${GO_BUILDFLAGS} -o bin/containerd-shim-runc-v2  ./cmd/containerd-shim-runc-v2
RUN go-assert-static.sh bin/*
RUN go-assert-boring.sh \
    bin/ctr \
    bin/containerd
RUN install -s bin/* /usr/local/bin
RUN containerd --version

FROM ubi
RUN microdnf update -y && \
    rm -rf /var/cache/yum
COPY --from=builder /usr/local/bin/ /usr/local/bin/
