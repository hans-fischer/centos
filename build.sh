#!/bin/bash
# CentOS container image

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.

# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

set -xe

trap cleanup INT EXIT

cleanup() {
  test -n "${ctr}" && buildah rm "${ctr}" || true
}

image="centos"

ctr="$(buildah from scratch)"
mnt="$(buildah mount ${ctr})"
yum_opts=(
  "--installroot=${mnt}"
  "--assumeyes"
  "--setopt=install_weak_deps=false"
  "--releasever=/"
  "--setopt=tsflags=nodocs"
)

yum ${yum_opts[@]} install centos-release.x86_64
yum ${yum_opts[@]} clean all

bom_sha256="$(rpm \
  --query \
  --all \
  --queryformat \
    '\{ "type": "rpm", "name": "%{NAME}", "version": "%{VERSION}", "release": "%{RELEASE}", "arch": "%{ARCH}"\}\n' \
  --dbpath="${mnt}"/var/lib/rpm \
  | sort | jq -cs '.' | sha256sum | awk '{ print $1; }')"

version="$( perl -0777 -ne 'print "$&\n" if /\d+(\.\d+)*/' \
  "${mnt}/etc/centos-release" )"

pushd "${mnt}"

mkdir -p run/lock

# System directories
rm -rf boot dev proc sys

# Unnecessary stuff
rm -rf home media mnt opt srv

# Stuff that prevents reproduceable build
rm -rf \
  etc/machine-id \
  lib/.build-id \
  etc/pki/ca-trust/extracted/java/cacerts \
  var/{cache,log}/* \
  tmp/*

echo 'root:x:0:0:root:/root:/bin/bash' > ./etc/passwd
echo 'root:x:0:' > ./etc/group
echo 'root:*:0:0:99999:7:::' > ./etc/shadow

popd

buildah run "${ctr}" -- localedef --force --inputfile=en_US --charmap=UTF-8 en_US.UTF-8

oci_prefix="org.opencontainers.image"
buildah config \
  --label "${oci_prefix}.authors=SDA SE Engineers <cloud@sda-se.com>" \
  --label "${oci_prefix}.url=https://quay.io/sdase/centos" \
  --label "${oci_prefix}.source=https://github.com/SDA-SE/centos" \
  --label "${oci_prefix}.version=${version}" \
  --label "${oci_prefix}.revision=$( git rev-parse HEAD )" \
  --label "${oci_prefix}.vendor=SDA SE Open Industry Solutions" \
  --label "${oci_prefix}.licenses=AGPL-3.0" \
  --label "${oci_prefix}.title=CentOS" \
  --label "${oci_prefix}.description=CentOS base image" \
  --label "io.sda-se.image.bom.sha256=$( echo "${bom_sha256}" )" \
  --env "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
  --cmd "/bin/sh" \
  "${ctr}"

buildah commit --rm --squash "${ctr}" "${image}" && ctr=

if [ -n "${BUILD_EXPORT_OCI_ARCHIVES}" ]
then
  skopeo copy \
    "containers-storage:localhost/${image}" \
    "oci-archive:${WORKSPACE:-.}/${image//:/-}.tar"

  buildah rmi "${image}"
fi
