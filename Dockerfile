FROM docker.io/centos:7

# https://github.com/opencontainers/image-spec/blob/master/annotations.md
LABEL \
  # Contact details of the people or organization responsible for the image
  org.opencontainers.image.authors="SDA SE Engineers <engineers@sda.se>" \
  # URL to find more information on the image
  org.opencontainers.image.url="https://quay.io/repository/sdase/centos" \
  # URL to get source code for building the image
  org.opencontainers.image.source="https://github.com/SDA-SE/centos" \
  # Version of the packaged software
  org.opencontainers.image.version="7" \
  # Source control revision identifier for the packaged software.
  org.opencontainers.image.vendor="SDA SE Open Industry Solutions" \
  # License(s) under which contained software is distributed as an SPDX License
  # Expression.
  org.opencontainers.image.licenses="UNLICENSED" \
  # Human-readable title of the image
  org.opencontainers.image.title="CentOS" \
  # Human-readable description of the software packaged in the image
  org.opencontainers.image.description="" \
  # Base image
  se.sda.oci.images.centos.base="docker.io/centos:7" \
  # https://docs.docker.com/engine/reference/builder/#label
  maintainer="engineers@sda.se"

RUN \
  yum -y update && \
  yum -y clean all && \
  rm -rf /var/cache/yum && \
  true
