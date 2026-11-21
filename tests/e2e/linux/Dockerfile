# Copyright 2026 Han Li and contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# The image the Linux suite runs its checks in: vfox from its release, checked
# against the digest the release publishes, and a Java runtime for Scala. It
# holds no plugin, which the suite mounts at /plugin for each container. Only
# linux/amd64 is covered.
FROM ubuntu:26.04

ARG VFOX_VERSION=1.1.0
ARG VFOX_SHA256=3b33c3c468b27bc17aecf0d6d3af24fe49fe204972984904a136a47b402a0ee4

ENV DEBIAN_FRONTEND=noninteractive

RUN set -o errexit -o nounset -o xtrace; \
    apt-get update; \
    apt-get install --assume-yes --no-install-recommends \
        ca-certificates \
        curl \
        default-jre-headless \
        tar; \
    rm --recursive --force /var/lib/apt/lists/*

RUN set -o errexit -o nounset -o xtrace; \
    archive="/tmp/vfox.tar.gz"; \
    curl --fail --silent --show-error --location --output "$archive" \
        "https://github.com/version-fox/vfox/releases/download/v${VFOX_VERSION}/vfox_${VFOX_VERSION}_linux_x86_64.tar.gz"; \
    echo "${VFOX_SHA256}  ${archive}" | sha256sum --check; \
    mkdir /tmp/vfox; \
    tar --extract --gzip --file "$archive" --directory /tmp/vfox --strip-components=1 "vfox_${VFOX_VERSION}_linux_x86_64/vfox"; \
    install --mode=0755 /tmp/vfox/vfox /usr/local/bin/vfox; \
    rm --recursive --force /tmp/vfox "$archive"; \
    vfox --version; \
    java -version

CMD ["sleep", "infinity"]
