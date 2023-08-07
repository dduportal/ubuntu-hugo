ARG DOCKER_VERSION=24.0.5
FROM docker:"${DOCKER_VERSION}"-dind AS dind

FROM ubuntu:22.04
LABEL maintainer="Damien Duportal <damien.duportal@gmail.com>"
# This value can be overriden with the `--platform=<new value>` flag of `docker build`.
ARG TARGETPLATFORM=linux/amd64

## Global setup
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8
ENV PATH="/usr/local/go/bin:/opt/W3C-Validator:${PATH}"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

## Setup and install required dependencies
# updating apt cache is executed in a single instruction to avoid cache miss when rebuilding the image in the future
RUN apt-get update \
  # Install and setup the locale from environment variable
  && apt-get install -y --no-install-recommends \
    ca-certificates=* \
    curl=7.* \
    locales=2.* \
  && locale-gen "${LANG}" \
  ## Add official nodejs distribution apt repository
  && curl -sL https://deb.nodesource.com/setup_14.x | bash - \
  # Install required packages
  && apt-get install -y --no-install-recommends \
    git=1:2.* \
    jq=1.* \
    make=4.* \
    nodejs=14.* \
    python3-pip=* \
    python3-setuptools=* \
    rsync=* \
    shellcheck=0.* \
    tar=1.* \
    unzip=6.* \
    zip=3.* \
  # Cleanup APT cache to ease extension of this image
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

## Install the hugo binary with a fixed version and control shasum
ARG HUGO_VERSION="0.115.4"
COPY ./checksums/hugo-${HUGO_VERSION}-checksums.txt /tmp/hugo-checksums.txt
# Download the Linux 64 bits default archive
RUN curl --silent --show-error --location --output /tmp/hugo.tgz \
    "https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_${HUGO_VERSION}_linux-$(dpkg --print-architecture).tar.gz" \
  # Control the checksum to ensure no one is messing up with the download
  && grep "$(sha256sum /tmp/hugo.tgz | awk '{print $1}')" /tmp/hugo-checksums.txt \
  # Extract to a directory part of the default PATH
  && tar xzf /tmp/hugo.tgz -C /usr/local/bin/ \
  # Cleanup
  && rm -f /tmp/hugo*

## Install Golang from binary distribution
ARG GO_VERSION="1.20.6"
COPY ./checksums/golang-${GO_VERSION}-checksums.txt /tmp/golang-checksums.txt
# No need to use C-Go and avoid requirement to GCC
ENV CGO_ENABLED=0
ENV GO11MODULES=on
RUN curl --silent --show-error --location --output /tmp/go.tgz \
    "https://golang.org/dl/go${GO_VERSION}.linux-$(dpkg --print-architecture).tar.gz" \
  # Control the checksum to ensure no one is messing up with the download
  && grep "$(sha256sum /tmp/go.tgz | awk '{print $1}')" /tmp/golang-checksums.txt \
  # Extract to a directory part of the default PATH
  && tar -C /usr/local -xzf /tmp/go.tgz \
  && rm -f /tmp/go.tgz

## Install Custom Tools for Edx Modules
ARG GOLANGCILINT_VERSION="1.53.3"
COPY ./checksums/golangci-lint-${GOLANGCILINT_VERSION}-checksums.txt /tmp/golangci-checksums.txt
RUN curl --silent --show-error --location --output /tmp/golangci-lint.deb \
    "https://github.com/golangci/golangci-lint/releases/download/v${GOLANGCILINT_VERSION}/golangci-lint-${GOLANGCILINT_VERSION}-linux-$(dpkg --print-architecture).deb" \
  # Control the checksum to ensure no one is messing up with the download
  && grep "$(sha256sum /tmp/golangci-lint.deb | awk '{print $1}')" /tmp/golangci-checksums.txt \
  # Extract to a directory part of the default PATH
  && dpkg -i /tmp/golangci-lint.deb \
  # Cleanup
  && rm -f /tmp/golangci-lint.deb

# W3C validator
RUN git clone https://github.com/holbertonschool/W3C-Validator.git /opt/W3C-Validator \
  # Sanity check
  && command -v w3c_validator.py

# markdown cli/lint
ARG MARKDOWNLINTCLI_VERSION=0.26.0
ARG MARKDOWNLINTLINKCHECK_VERSION=3.8.6
RUN npm install --global \
  markdownlint-cli@"${MARKDOWNLINTCLI_VERSION}" \
  markdown-link-check@"${MARKDOWNLINTLINKCHECK_VERSION}"

# yamllint
ARG YAMLLINT_VERSION=1.*
RUN python3 -m pip install --no-cache-dir \
  requests==2.* yamllint=="${YAMLLINT_VERSION}"

ARG YQ_VERSION="4.5.0"
ARG YQ_CHECKSUM="b08830201aed3b75a32aebf29139877158904fe9efb05af628f43c239fb95830"
RUN curl --silent --show-error --location --output /usr/local/bin/yq \
    "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_${TARGETPLATFORM#*/}" \
    # Control the checksum to ensure no one is messing up with the download
  && sha256sum /usr/local/bin/yq | grep -q "${YQ_CHECKSUM}" \
  # Extract to a directory part of the default PATH
  && chmod a+x /usr/local/bin/yq

# Install Docker Engine
ARG DOCKER_VERSION=24.0.5
RUN curl --fail --silent --show-error --location https://get.docker.com -o /tmp/install-docker.sh \
  && bash /tmp/install-docker.sh --version "${DOCKER_VERSION}" \
  && rm -f /tmp/install-docker.sh

# Install Docker Compose plugin
ARG DOCKER_COMPOSE_VERSION=2.20.2
RUN apt-get update --quiet && \
  apt-get install --yes --no-install-recommends docker-compose-plugin="${DOCKER_COMPOSE_VERSION}"* \
  # Cleanup APT cache to ease extension of this image
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

# Install Docker BuildX plugin
ARG DOCKER_BUILDX_VERSION=0.11.2
RUN apt-get update --quiet && \
  apt-get install --yes --no-install-recommends docker-buildx-plugin="${DOCKER_BUILDX_VERSION}"* \
  # Cleanup APT cache to ease extension of this image
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

# set up subuid/subgid so that "--userns-remap=default" works out-of-the-box
RUN set -eux; \
	addgroup --system dockremap; \
	adduser --system dockremap; \
  adduser dockremap dockremap; \
	echo 'dockremap:165536:65536' >> /etc/subuid; \
	echo 'dockremap:165536:65536' >> /etc/subgid

COPY --from=dind /usr/local/bin/dind /usr/local/bin/dind
COPY --from=dind /usr/local/bin/dockerd-entrypoint.sh /usr/local/bin/dockerd-entrypoint.sh
COPY --from=dind /usr/local/bin/docker-init /usr/local/bin/docker-init

VOLUME /var/lib/docker

ARG HADOLINT_VERSION=2.12.0
COPY ./checksums/hadolint-${HADOLINT_VERSION}-checksums.txt /tmp/hadolint-checksums.txt
RUN if [ "$(dpkg --print-architecture)" == "amd64" ]; then cpu_arch='x86_64'; else cpu_arch='arm64';fi; \
  curl --fail --silent --show-error --location --output /usr/local/bin/hadolint \
    "https://github.com/hadolint/hadolint/releases/download/v${HADOLINT_VERSION}/hadolint-Linux-${cpu_arch}" \
  # Control the checksum to ensure no one is messing up with the download
  && grep "$(sha256sum /usr/local/bin/hadolint | awk '{print $1}')" /tmp/hadolint-checksums.txt \
  && chmod a+x /usr/local/bin/hadolint

ARG CST_VERSION=1.16.0
COPY ./checksums/cst-${CST_VERSION}-checksums.txt /tmp/cst-checksums.txt
RUN curl --fail --silent --show-error --location --output /usr/local/bin/container-structure-test \
    "https://github.com/GoogleContainerTools/container-structure-test/releases/download/v1.16.0/container-structure-test-linux-$(dpkg --print-architecture)" \
  # Control the checksum to ensure no one is messing up with the download
  && grep "$(sha256sum /usr/local/bin/container-structure-test | awk '{print $1}')" /tmp/cst-checksums.txt \
  && chmod a+x /usr/local/bin/container-structure-test
