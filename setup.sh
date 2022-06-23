#!/bin/sh

apt update
apt install -y parted
update-rc.d resize2fs_once defaults
