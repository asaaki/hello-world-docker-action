# syntax=docker/dockerfile:1.2

## global args
ARG APP_NAME=action

# use it only if you really need to squeeze the bytes
# note: alpine base already comes with ~5.61 MB (alpine 3.11)
ARG STRIP=1
ARG COMPRESS=0

#########################
##### builder layer #####
#########################

FROM rust:1.50-slim-buster as builder

ENV BUILD_CACHE_BUSTER="2021-03-17T00:00:00"
ENV DEB_PACKAGES="ca-certificates cmake curl file g++ gcc gcc-multilib git libssl-dev linux-headers-amd64 make musl-tools patch pkg-config wget xz-utils"

# @see https://github.com/moby/buildkit/blob/master/frontend/dockerfile/docs/experimental.md#example-cache-apt-packages
RUN rm -f /etc/apt/apt.conf.d/docker-clean \
  && echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache

RUN \
  --mount=type=cache,target=/var/cache/apt \
  --mount=type=cache,target=/var/lib/apt \
  echo "===== Build environment =====" \
  && uname -a \
  && echo "===== Dependencies =====" \
  && apt-get update \
  && apt-get install -y --no-install-recommends $DEB_PACKAGES \
  && ln -s /usr/bin/musl-gcc /usr/bin/musl-g++ \
  && echo "===== Rust target: musl =====" \
  && rustup target add x86_64-unknown-linux-musl \
  && echo "===== UPX =====" \
  && wget -O upx.tar.xz https://github.com/upx/upx/releases/download/v3.96/upx-3.96-amd64_linux.tar.xz \
  && tar -xf upx.tar.xz --directory /bin --strip-components=1 $(tar -tf upx.tar.xz | grep -E 'upx$') \
  && rm -f upx.tar.xz \
  && echo "===== Toolchain =====" \
  && rustup --version \
  && cargo --version \
  && rustc --version \
  && echo "Rust builder image done."

#######################
##### build layer #####
#######################

FROM builder as build

# @see https://docs.docker.com/engine/reference/builder/#understand-how-arg-and-from-interact
ARG APP_NAME
ARG BUILD_MODE
ARG STRIP
ARG COMPRESS

# create stub app for better build caching
RUN USER=root cargo new --bin /app

WORKDIR /app

COPY .cargo /app/.cargo
COPY Cargo.* /app/

# ENV RUSTFLAGS="-C target-feature=-crt-static"

RUN \
  --mount=type=cache,target=/usr/local/cargo/registry \
  --mount=type=cache,target=/app/target \
  cargo fetch \
  && cargo build --release --target=x86_64-unknown-linux-musl \
  && rm -rf /app/src

COPY build.rs /app/
COPY src /app/src

RUN \
  --mount=type=cache,target=/usr/local/cargo/registry \
  --mount=type=cache,target=/app/target \
  find src -exec touch {} + \
 && cargo install --root /app --target=x86_64-unknown-linux-musl --path .
# remove debug symbols
RUN [ "${STRIP}" = "1" ] && (echo "Stripping debug symbols ..."; strip bin/${APP_NAME}) || echo "No stripping enabled"
# compress binary; upx docs: https://github.com/upx/upx/blob/master/doc/upx.pod
RUN [ "${COMPRESS}" = "1" ] && (echo "Compressing binary ..."; upx --best bin/${APP_NAME}) || echo "No compression enabled"
RUN du -h bin/${APP_NAME}

######################
##### base layer #####
######################

FROM alpine:3.13 as base
# RUN apk update --no-cache && apk upgrade --no-cache && apk add --no-cache tini
WORKDIR /app

####################
##### run layer ####
####################

# This is why we do not want to use 'FROM scratch',
# otherwise the user within the container would be still root

FROM base as run
RUN addgroup -g 1001 appuser \
 && adduser  -u 1001 -G appuser -H -D appuser
USER 1001

#######################
##### final image #####
#######################

FROM run as production

ARG APP_NAME

COPY --from=build --chown=appuser:appuser /app/bin/${APP_NAME} /

ENTRYPOINT [ "/action" ]
