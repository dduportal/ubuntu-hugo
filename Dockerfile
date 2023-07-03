FROM ubuntu:18.04
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
    python3-pip=9.* \
    python3-setuptools=39.* \
    rsync=* \
    shellcheck=0.* \
    tar=1.* \
    unzip=6.* \
    zip=3.* \
  # Cleanup APT cache to ease extension of this image
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

## Install the hugo binary with a fixed version and control shasum
ARG HUGO_VERSION="0.80.0"
ARG HUGO_CHECKSUM="b3a259bbe633e2f9182f8ecfc1b5cee6a7cfc4c970defe5f29c9959f2ef3259b"
# Download the Linux 64 bits default archive
RUN curl --silent --show-error --location --output /tmp/hugo.tgz \
    "https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_${HUGO_VERSION}_Linux-64bit.tar.gz" \
  # Control the checksum to ensure no one is messing up with the download
  && sha256sum /tmp/hugo.tgz | grep -q "${HUGO_CHECKSUM}" \
  # Extract to a directory part of the default PATH
  && tar xzf /tmp/hugo.tgz -C /usr/local/bin/ \
  # Cleanup
  && rm -f /tmp/hugo.tgz

## Install Golang from binary distribution
ARG GO_VERSION="1.15.7"
ARG GO_CHECKSUM="0d142143794721bb63ce6c8a6180c4062bcf8ef4715e7d6d6609f3a8282629b3"
# No need to use C-Go and avoid requirement to GCC
ENV CGO_ENABLED=0
ENV GO11MODULES=on
RUN curl --silent --show-error --location --output /tmp/go.tgz \
    "https://golang.org/dl/go${GO_VERSION}.linux-${TARGETPLATFORM#*/}.tar.gz" \
  # Control the checksum to ensure no one is messing up with the download
  && sha256sum /tmp/go.tgz | grep -q "${GO_CHECKSUM}" \
  # Extract to a directory part of the default PATH
  && tar -C /usr/local -xzf /tmp/go.tgz \
  && rm -f /tmp/go.tgz


## Install Custom Tools for Edx Modules
ARG GOLANGCILINT_VERSION="1.36.0"
ARG GOLANGCILINT_CHECKSUM="c36e9c7153e87dabcbc424c3a86b32676631ab94db4b5d7d2907675aea5c6709"
RUN curl --silent --show-error --location --output /tmp/golangci-lint.deb \
    "https://github.com/golangci/golangci-lint/releases/download/v${GOLANGCILINT_VERSION}/golangci-lint-${GOLANGCILINT_VERSION}-linux-${TARGETPLATFORM#*/}.deb" \
    # Control the checksum to ensure no one is messing up with the download
  && sha256sum /tmp/golangci-lint.deb | grep -q "${GOLANGCILINT_CHECKSUM}" \
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
