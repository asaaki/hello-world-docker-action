# syntax=docker/dockerfile:1-labs

FROM rust:1.86.0-bookworm AS builder

ENV DEBIAN_FRONTEND noninteractive

# https://github.com/moby/buildkit/blob/master/frontend/dockerfile/docs/reference.md#example-cache-apt-packages
RUN rm -f /etc/apt/apt.conf.d/docker-clean; \
    echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache

RUN \
  --mount=type=cache,target=/var/cache/apt,sharing=locked \
  --mount=type=cache,target=/var/lib/apt,sharing=locked \
    /bin/sh -c set -ex; \
    apt-get update && apt-get upgrade; \
    apt-get install -y ca-certificates clang cmake libnss3 libnss3-dev libssl-dev mold pkg-config

RUN update-ca-certificates --fresh

COPY --link --from=ghcr.io/markentier/utilities:all-in-one /usr/bin/magicpak /usr/bin/magicpak

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

# Note: if you want to inspect linked shared libs;
# /lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 --list /cti/cti_server
# https://github.com/coord-e/magicpak#note-on-name-resolution-and-glibc
RUN magicpak \
    $(find /app/bin -executable -type f) \
    /bundle \
    --install-to /app/bin/ \
    --include /etc/passwd \
    --include /etc/group \
    --include '/lib/x86_64-linux-gnu/libnss_*' \
    -v

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
COPY --from=builder /usr/lib/ssl/certs /usr/lib/ssl/certs
COPY --link --from=ghcr.io/markentier/utilities:all-in-one /busybox /bin

USER 1001:1001

ENTRYPOINT ["/app/bin/action"]
