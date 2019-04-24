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
  test -f "${yum_config_file}" && rm "${yum_config_file}" || true
  test -f "${rpm_public_key_file}" && rm "${rpm_public_key_file}" || true
}

image="centos"

# Create container
ctr="$(buildah from scratch)"

# Mount container
mnt="$(buildah mount ${ctr})"

# Initialize RPM database
mkdir -p "${mnt}/var/lib/rpm"
rpm --root "${mnt}" --initdb

# Download CentOS GnuPG key via HTTPS
rpm_public_key_file="$(mktemp)"
curl --location https://www.centos.org/keys/RPM-GPG-KEY-CentOS-7 \
  > "${rpm_public_key_file}"

# Import key so that package signature can be checked
rpm --root "${mnt}" --import "${rpm_public_key_file}"

# Write Yum config file that is used during initial installation
yum_config_file="$(mktemp)"
cat <<EOD > "${yum_config_file}"
[centos-buildah-base]
name=CentOS-7-Base
baseurl=http://mirror.centos.org/centos/7/os/x86_64
gpgcheck=1
EOD

# Options that are used with every `yum` command
yum_opts=(
  "--config=${yum_config_file}"
  "--disablerepo=*"
  "--enablerepo=centos-buildah-base"
  "--disableplugin=*"
  "--installroot=${mnt}"
  "--assumeyes"
  "--setopt=install_weak_deps=false"
  "--releasever=7"
  "--setopt=tsflags=nodocs"
)

# Install CentOS
yum ${yum_opts[@]} install centos-release.x86_64
yum ${yum_opts[@]} clean all

# Get a bill of materials
bill_of_materials="$(rpm \
  --query \
  --all \
  --queryformat "%{NAME} %{VERSION} %{RELEASE} %{ARCH}" \
  --dbpath="${mnt}"/var/lib/rpm \
  | sort )"

# Get bill of materials hash – the content
# of this script is included in hash, too.
bill_of_materials_hash="$( (cat "${0}"; echo "${bill_of_materials}") \
  | sha256sum | awk '{ print $1; }' )"

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
  --label "io.sda-se.image.bill-of-materials-hash=$( \
    echo "${bill_of_materials_hash}" )" \
  --env "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
  --env "LANG=en_US.UTF-8" \
  --env "LC_ALL=en_US.UTF-8" \
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
