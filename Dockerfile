FROM debian:buster-slim AS zip_downloader
LABEL maintainer="Michael Lynch <michael@mtlynch.io>"

ARG SIA_VERSION="1.4.2.1"
ARG SIA_PACKAGE="Sia-v${SIA_VERSION}-linux-amd64"
ARG SIA_ZIP="${SIA_PACKAGE}.zip"
ARG SIA_RELEASE="https://sia.tech/static/releases/${SIA_ZIP}"

ARG REPERTORY_RELEASE

RUN apt-get update
RUN apt-get install -y \
      wget \
      curl \
      jq \
      unzip

RUN wget "$SIA_RELEASE" && \
      mkdir /sia && \
      unzip -j "$SIA_ZIP" "${SIA_PACKAGE}/siac" -d /sia && \
      unzip -j "$SIA_ZIP" "${SIA_PACKAGE}/siad" -d /sia

RUN curl -o /tmp/repertory.zip -L $(curl -sX GET "https://api.bitbucket.org/2.0/repositories/blockstorage/repertory/downloads?pagelen=100" \
	| jq -r 'first(.values[] | select(.links.self.href | endswith("_debian10.zip")).links.self.href)');
RUN mkdir /repertory
RUN unzip -j /tmp/repertory.zip -d /repertory

FROM debian:buster-slim
ARG SIA_DIR="/sia"
ARG SIA_DATA_DIR="/sia-data"

ARG REPERTORY_DIR="/repertory"

COPY --from=zip_downloader /sia/siac "${SIA_DIR}/siac"
COPY --from=zip_downloader /sia/siad "${SIA_DIR}/siad"

COPY --from=zip_downloader /repertory "${REPERTORY_DIR}"

RUN apt-get update
RUN apt-get install -y socat

# Required repertory packages
RUN apt-get -y install libfuse-dev 

# Workaround for backwards compatibility with old images, which hardcoded the
# Sia data directory as /mnt/sia. Creates a symbolic link so that any previous
# path references stored in the Sia host config still work.
RUN ln --symbolic "$SIA_DATA_DIR" /mnt/sia

EXPOSE 9980 9981 9982 20000

WORKDIR "$SIA_DIR"

ENV SIA_DATA_DIR "$SIA_DATA_DIR"
ENV SIA_MODULES gctwhr
ENV REPERTORY_DATA_DIR "/mnt/repertory"

RUN mkdir REPERTORY_DATA_DIR

ENTRYPOINT socat tcp-listen:9980,reuseaddr,fork tcp:localhost:8000 & \
  ./siad \
    --modules "$SIA_MODULES" \
    --sia-directory "$SIA_DATA_DIR" \
    --api-addr "localhost:8000" && \
  /repertory/repertory -o big_writes "$REPERTORY_DATA_DIR"
