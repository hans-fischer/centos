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

dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
build_dir="${dir}/build"

trap cleanup INT EXIT
cleanup() {
  test -n "${ctr}" && buildah rm "${ctr}" || true
  test -f "${yum_config_file}" && rm "${yum_config_file}" || true
  test -f "${rpm_public_key_file}" && rm "${rpm_public_key_file}" || true
}

# #############################################################################
# CENTOS 8
# #############################################################################

# Create container
ctr="$( buildah from scratch )"

# Mount container
mnt="$( buildah mount "${ctr}" )"

# Initialize RPM database.
mkdir -p "${mnt}"/var/lib/rpm
rpm --root "${mnt}" --initdb

# Download CentOS GnuPG key via HTTPS
rpm_public_key_file="$( mktemp )"
curl --location https://www.centos.org/keys/RPM-GPG-KEY-CentOS-Official \
  > "${rpm_public_key_file}"

# Import key so that package signature can be checked
rpm --root "${mnt}" --import "${rpm_public_key_file}"

# Write Yum config file that is used during initial installation
yum_config_file="$( mktemp )"
cat <<EOD > "${yum_config_file}"
[centos-buildah-baseos]
name=CentOS-8 - BaseOS
baseurl=http://mirror.centos.org/centos/8/BaseOS/x86_64/os/
gpgcheck=1
enabled=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial

[centos-buildah-appstream]
name=CentOS-8 - AppStream
baseurl=http://mirror.centos.org/centos/8/AppStream/x86_64/os/
gpgcheck=1
enabled=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial

[centos-buildah-extras]
name=CentOS-8 - Extras
baseurl=http://mirror.centos.org/centos/8/extras/x86_64/os/
gpgcheck=1
enabled=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial
EOD

# Options that are used with every `yum` command
dnf_opts=(
  "--config=${yum_config_file}"
  "--disablerepo=*"
  "--enablerepo=centos-buildah-baseos,centos-buildah-appstream,centos-buildah-extras"
  "--disableplugin=*"
  "--installroot=${mnt}"
  "--assumeyes"
  "--setopt=install_weak_deps=false"
  "--releasever=8"
  "--setopt=tsflags=nocontexts,nodocs"
)

# Install CentOS
dnf ${dnf_opts[@]} install bash coreutils-single rpm glibc-minimal-langpack rootfiles langpacks-en libstdc++
dnf ${dnf_opts[@]} clean all

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

popd

oci_prefix="org.opencontainers.image"
buildah config \
  --label "${oci_prefix}.authors=SDA SE Engineers <engineers@sda-se.io>" \
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
  --env "LANG=C.utf8" \
  --cmd "/bin/bash" \
  "${ctr}"

# Create image
image="centos:8"
image_build="${image}.${RANDOM}"
buildah commit --quiet --rm --squash "${ctr}" "${image_build}" && ctr=

if [ -n "${BUILD_EXPORT_OCI_ARCHIVES}" ]
then
  mkdir --parent "${build_dir}"
  buildah push --quiet \
    "${image_build}" \
    "oci-archive:${build_dir}/${image//:/-}.tar"
  buildah rmi "${image_build}"
fi

cleanup

# #############################################################################
# CENTOS 7 
# #############################################################################

# Create container
ctr="$( buildah from scratch )"

# Mount container
mnt="$( buildah mount "${ctr}" )"

# Initialize RPM database.
mkdir -p "${mnt}"/var/lib/rpm
rpm --root "${mnt}" --initdb

# Download CentOS GnuPG key via HTTPS
rpm_public_key_file="$( mktemp )"
curl --location https://www.centos.org/keys/RPM-GPG-KEY-CentOS-7 \
  > "${rpm_public_key_file}"

# Import key so that package signature can be checked
rpm --root "${mnt}" --import "${rpm_public_key_file}"

# Write Yum config file that is used during initial installation
yum_config_file="$( mktemp )"
cat <<EOD > "${yum_config_file}"
[centos-buildah-base]
name=CentOS-7-Base
baseurl=http://mirror.centos.org/centos/7/os/x86_64
gpgcheck=1
[centos-buildah-updates]
name=CentOS-7 - Updates
baseurl=http://mirror.centos.org/centos/7/updates/x86_64/
gpgcheck=1
EOD

# Options that are used with every `yum` command
yum_opts=(
  "--config=${yum_config_file}"
  "--disablerepo=*"
  "--enablerepo=centos-buildah-base,centos-buildah-updates"
  "--disableplugin=*"
  "--installroot=${mnt}"
  "--assumeyes"
  "--setopt=install_weak_deps=false"
  "--releasever=7"
  "--setopt=tsflags=nocontexts,nodocs"
)

# Install CentOS
yum ${yum_opts[@]} install centos-release.x86_64
yum ${yum_opts[@]} install coreutils
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
  --label "${oci_prefix}.authors=SDA SE Engineers <engineers@sda-se.io>" \
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

# Create image
image="centos:7"
image_build="${image}.${RANDOM}"
buildah commit --quiet --rm --squash "${ctr}" "${image_build}" && ctr=

if [ -n "${BUILD_EXPORT_OCI_ARCHIVES}" ]
then
  mkdir --parent "${build_dir}"
  buildah push --quiet \
    "${image_build}" \
    "oci-archive:${build_dir}/${image//:/-}.tar"
  buildah rmi "${image_build}"
fi
