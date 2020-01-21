FROM debian:stretch-slim AS zip_downloader
LABEL maintainer="Michael Lynch <michael@mtlynch.io>"

ARG SIA_VERSION="1.4.2.0"
ARG SIA_PACKAGE="Sia-v${SIA_VERSION}-linux-amd64"
ARG SIA_ZIP="${SIA_PACKAGE}.zip"
ARG SIA_RELEASE="https://sia.tech/static/releases/${SIA_ZIP}"

ARG REPERTORY_VERSION="1.2.0-release_cd9e992"
ARG REPERTORY_PACKAGE="repertory_${REPERTORY_VERSION}_debian9"
ARG REPERTORY_ZIP="${REPERTORY_PACKAGE}.zip"
ARG REPERTORY_RELEASE="https://bitbucket.org/blockstorage/repertory/downloads/${REPERTORY_ZIP}"

RUN apt-get update
RUN apt-get install -y \
      wget \
      unzip

RUN wget "$SIA_RELEASE" && \
      mkdir /sia && \
      unzip -j "$SIA_ZIP" "${SIA_PACKAGE}/siac" -d /sia && \
      unzip -j "$SIA_ZIP" "${SIA_PACKAGE}/siad" -d /sia

RUN wget "$REPERTORY_RELEASE" && \
      mkdir /repertory && \
      unzip -j "$REPERTORY_ZIP" -d /repertory

FROM debian:stretch-slim
ARG SIA_DIR="/sia"
ARG SIA_DATA_DIR="/sia-data"

ARG REPERTORY_DIR="/repertory"

COPY --from=zip_downloader /sia/siac "${SIA_DIR}/siac"
COPY --from=zip_downloader /sia/siad "${SIA_DIR}/siad"

COPY --from=zip_downloader /repertory "${REPERTORY_DIR}"

RUN apt-get update
RUN apt-get install -y socat

# Required system packages
RUN apt-get update && apt-get -y install \
  apt-utils \
  build-essential \
  curl \
  pkg-config \
  cmake \
  make \
  gcc \
  g++ \
  libfuse-dev \
  libstdc++-6-dev \
  diffutils \
  git \
  tar \
  zlib1g-dev \
  zip

# Workaround for backwards compatibility with old images, which hardcoded the
# Sia data directory as /mnt/sia. Creates a symbolic link so that any previous
# path references stored in the Sia host config still work.
RUN ln --symbolic "$SIA_DATA_DIR" /mnt/sia

EXPOSE 9980 9981 9982 20000

WORKDIR "$SIA_DIR"

ENV SIA_DATA_DIR "$SIA_DATA_DIR"
ENV SIA_MODULES gctwhr
ENV REPERTORY_DATA_DIR "/mnt/repertory"

ENTRYPOINT socat tcp-listen:9980,reuseaddr,fork tcp:localhost:8000 & \
  ./siad \
    --modules "$SIA_MODULES" \
    --sia-directory "$SIA_DATA_DIR" \
    --api-addr "localhost:8000" && \
  repertory/repertory -f -o big_writes "$REPERTORY_DATA_DIR"
