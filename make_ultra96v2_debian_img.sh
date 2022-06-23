#!/bin/bash

# ikwzm 氏の debian イメージをパーティーション拡張可能な形で img 化する



########################################
# 設定
########################################

VERSION="2021.1.1"
TAG="v2021.1.1"
IMG_FILE="ultra96v2-debian-v2021.1.1.img"

TGZ_FILE="ZynqMP-FPGA-Linux-${TAG}.tar.gz"

WORD_DIR=`pwd`


########################################
# イメージ取得(私の OneDriveから)
########################################

# ZynqMP-FPGA-Linux-v2021.1.1.tar.gz
if [ ! -f $TGZ_FILE ]; then
#   wget -O $TGZ_FILE https://github.com/ikwzm/ZynqMP-FPGA-Linux/archive/refs/tags/$TAG.tar.gz
    wget -O $TGZ_FILE 'https://onedrive.live.com/download?cid=E643EA309C96C6F6&resid=E643EA309C96C6F6%2142121&authkey=ACAH_X1CZF8a6fU'
fi
tar zxvf $TGZ_FILE


########################################
# イメージ作成
########################################

MNT_P1="/mnt/loop_img_p1"
MNT_P2="/mnt/loop_img_p2"

# 空いてる loop を得る
DEV_LOOP=`sudo losetup -f`

# 空のイメージを作る
rm -f $IMG_FILE
truncate -s 6GiB $IMG_FILE

# パーティーションを作る
sudo losetup $DEV_LOOP $IMG_FILE
sudo parted $DEV_LOOP -s mklabel msdos -s mkpart primary fat32 1048576B 315621375B -s mkpart primary ext4 315621376B 100% -s set 1 boot
sudo mkfs.vfat ${DEV_LOOP}p1
sudo mkfs.ext4 ${DEV_LOOP}p2

# マウントする
sudo mkdir -p $MNT_P1
sudo mkdir -p $MNT_P2
sudo mount ${DEV_LOOP}p1 $MNT_P1
sudo mount ${DEV_LOOP}p2 $MNT_P2

# ファイルコピー
cd ZynqMP-FPGA-Linux-${VERSION}
sudo cp target/Ultra96-V2/boot/* $MNT_P1

sudo tar xfz debian11-rootfs-vanilla.tgz -C $MNT_P2
sudo mkdir $MNT_P2/home/fpga/debian
sudo cp linux-image-5.4.0-xlnx-v2020.2-zynqmp-fpga_5.4.0-xlnx-v2020.2-zynqmp-fpga-3_arm64.deb     $MNT_P2/home/fpga/debian
sudo cp linux-headers-5.4.0-xlnx-v2020.2-zynqmp-fpga_5.4.0-xlnx-v2020.2-zynqmp-fpga-3_arm64.deb   $MNT_P2/home/fpga/debian
sudo cp fclkcfg-5.4.0-xlnx-v2020.2-zynqmp-fpga_1.7.2-1_arm64.deb                                  $MNT_P2/home/fpga/debian
sudo cp u-dma-buf-5.4.0-xlnx-v2020.2-zynqmp-fpga_3.2.4-0_arm64.deb                                $MNT_P2/home/fpga/debian
sudo cp linux-image-5.10.0-xlnx-v2021.1-zynqmp-fpga_5.10.0-xlnx-v2021.1-zynqmp-fpga-4_arm64.deb   $MNT_P2/home/fpga/debian
sudo cp linux-headers-5.10.0-xlnx-v2021.1-zynqmp-fpga_5.10.0-xlnx-v2021.1-zynqmp-fpga-4_arm64.deb $MNT_P2/home/fpga/debian
sudo cp fclkcfg-5.10.0-xlnx-v2021.1-zynqmp-fpga_1.7.2-1_arm64.deb                                 $MNT_P2/home/fpga/debian
sudo cp u-dma-buf-5.10.0-xlnx-v2021.1-zynqmp-fpga_3.2.4-0_arm64.deb                               $MNT_P2/home/fpga/debian

sudo mkdir $MNT_P2/mnt/boot
sudo sh -c "cat <<EOT >> $MNT_P2/etc/fstab
/dev/mmcblk0p1  /mnt/boot   auto    defaults    0   0
EOT"

cd $WORD_DIR

# 自動パーティーション拡張を仕込む
sudo cp setup.sh       $MNT_P2/
sudo chmod 755         $MNT_P2/setup.sh
sudo cp resize2fs_once $MNT_P2/etc/init.d/
sudo chmod 755         $MNT_P2/etc/init.d/resize2fs_once

sudo mv $MNT_P2/etc/resolv.conf      $MNT_P2/etc/resolv.conf.org
sudo cp /etc/resolv.conf             $MNT_P2/etc
sudo cp /usr/bin/qemu-aarch64-static $MNT_P2/usr/bin

sudo chroot $MNT_P2/ ./setup.sh

sudo mv $MNT_P2/etc/resolv.conf.org $MNT_P2/etc/resolv.conf
sudo rm $MNT_P2/usr/bin/qemu-aarch64-static
sudo rm $MNT_P2/setup.sh

# アンマウント前にサイズ表示
df

# アンマウント
sync
sudo umount $MNT_P1
sudo umount $MNT_P2
sudo losetup -d $DEV_LOOP
sync

sudo tmdir -p $MNT_P1
sudo tmdir -p $MNT_P2
