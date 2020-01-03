# CentOS image

This is the base image of all images used within the SDA platform. Currently,
this image is rebuilt once a day from the official centos image and all updates
that are available at the time of building.

* Source code: <https://github.com/SDA-SE/centos>
* Image repository: [quay.io/sdase/centos](
  https://quay.io/repository/sdase/centos?tab=tags)

## Build on centos 7

Enable user namespace:
```
grubby --args="namespace.unpriv_enable=1 user_namespace.enable=1" --update-kernel="$(grubby --default-kernel)"

echo "user.max_user_namespaces=15000" >> /etc/sysctl.conf

reboot
```