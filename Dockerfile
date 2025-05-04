# syntax=docker/dockerfile:1-labs

FROM rust:1.86.0-bookworm AS builder

ARG MAGICPAK_VER=1.4.0
ARG MAGICPAK_ARCH=x86_64

ARG UPX_VER=4.1.0
ARG UPX_ARCH=amd64

ENV DEBIAN_FRONTEND noninteractive

# https://github.com/moby/buildkit/blob/master/frontend/dockerfile/docs/reference.md#example-cache-apt-packages
RUN rm -f /etc/apt/apt.conf.d/docker-clean; \
    echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache

RUN \
  --mount=type=cache,target=/var/cache/apt,sharing=locked \
  --mount=type=cache,target=/var/lib/apt,sharing=locked \
    /bin/sh -c set -ex; \
    apt-get update && apt-get upgrade; \
    apt-get install -y ca-certificates clang cmake libssl-dev mold pkg-config

RUN update-ca-certificates --fresh

ADD https://github.com/coord-e/magicpak/releases/download/v${MAGICPAK_VER}/magicpak-${MAGICPAK_ARCH}-unknown-linux-musl /usr/bin/magicpak
RUN chmod +x /usr/bin/magicpak
RUN wget -O upx.tar.xz https://github.com/upx/upx/releases/download/v${UPX_VER}/upx-${UPX_VER}-${UPX_ARCH}_linux.tar.xz && \
    tar -xf upx.tar.xz --directory /usr/bin --strip-components=1 $(tar -tf upx.tar.xz | grep -E 'upx$')

RUN adduser \
    --disabled-password \
    --gecos "" \
    --home "/nonexistent" \
    --shell "/sbin/nologin" \
    --no-create-home \
    --uid 1001 \
    appuser

RUN mkdir -p /var/empty

WORKDIR /app

COPY . .

RUN \
  --mount=type=cache,target=/usr/local/cargo/registry \
  --mount=type=cache,target=/app/target \
    cargo install --root /app --path .

# Note: Remove compression if you want to inspect linked shared libs;
# due to upx this gets hidden (the wrapper bin is static).
# In production image you can then run:
# /lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 --list /app/bin/cti_server
RUN magicpak -v \
    --include /etc/passwd \
    --include /etc/group \
    --compress --upx-arg --best --upx-arg --lzma \
    /app/bin/action /bundle

### busybox ###

FROM busybox:1.37.0-glibc AS shell

WORKDIR /shell

RUN cd /shell; \
    cp /bin/busybox .; \
    for c in $(./busybox --list); do ln -s ./busybox ./$c; done

# ### prod image ### #

# note: do not use :nonroot tag, AS it does not work with fly.io
FROM gcr.io/distroless/cc AS production

ARG RUST_BACKTRACE

ENV PATH=/app/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ENV RUST_BACKTRACE=${RUST_BACKTRACE}

COPY --from=builder --chown=1001:1001 /bundle /.
COPY --from=builder /var/empty /var/empty
COPY --from=shell /shell /bin

USER 1001:1001

ENTRYPOINT [ "/app/bin/action" ]
