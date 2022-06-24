
#!/bin/bash

# dd 等で保存した img をパーティーション拡張可能な形で再 img 化する

########################################
# 設定
########################################

if [ $# -lt 1 ]; then
  echo "no input files"
  exit 1
fi
SRC_IMG=$1

DST_IMG="sd_card.img"
if [ $# -eq 2 ]; then
  DST_IMG=$2
fi

echo $SRC_IMG
echo $DST_IMG

MNT_P1="/mnt/loop_img_p1"
MNT_P2="/mnt/loop_img_p2"

DATE_TAG=$(date +%Y%m%d%H%M)
BOOT_TGZ="boot-$DATE_TAG.tgz"
ROOTFS_TGZ="rootfs-$DATE_TAG.tgz"


########################################
# 既存イメージをtgz にバックアップ
########################################

# 空いてるloopを得る
DEV_LOOP=`sudo losetup -f`

# イメージをマウント
sudo mkdir -p $MNT_P1
sudo mkdir -p $MNT_P2
sudo losetup $DEV_LOOP $SRC_IMG
sudo mount ${DEV_LOOP}p1 $MNT_P1
sudo mount ${DEV_LOOP}p2 $MNT_P2

# バックアップ
sudo tar zcf $BOOT_TGZ   -C $MNT_P1 .
sudo tar zcf $ROOTFS_TGZ -C $MNT_P2 .

# イメージをアンマウント
sync
sudo umount $MNT_P1
sudo umount $MNT_P2
sudo losetup -d $DEV_LOOP
sync
sudo rmdir $MNT_P1
sudo rmdir $MNT_P2



########################################
# 新しいイメージを作成
########################################

# 空いてるloopを得る
DEV_LOOP=`sudo losetup -f`

# 空のイメージを作る
rm -f $DST_IMG
truncate -s 4GiB $DST_IMG

# パーティーションを作る
sudo losetup $DEV_LOOP $DST_IMG
sudo parted $DEV_LOOP -s mklabel msdos -s mkpart primary fat32 1048576B 315621375B -s mkpart primary ext4 315621376B 100% -s set 1 boot
sudo mkfs.vfat ${DEV_LOOP}p1
sudo mkfs.ext4 ${DEV_LOOP}p2

# ボリュームラベル
sudo fatlabel ${DEV_LOOP}p1 BOOT
sudo e2label  ${DEV_LOOP}p2 rootfs

# マウントする
sudo mkdir -p $MNT_P1
sudo mkdir -p $MNT_P2
sudo mount ${DEV_LOOP}p1 $MNT_P1
sudo mount ${DEV_LOOP}p2 $MNT_P2

# ファイルコピー
sudo tar zxf $BOOT_TGZ   -C $MNT_P1
sudo tar zxf $ROOTFS_TGZ -C $MNT_P2

# 自動パーティーション拡張を仕込む
sudo cp resize2fs_once $MNT_P2/etc/init.d/
sudo chmod 755         $MNT_P2/etc/init.d/resize2fs_once
sudo cp setup.sh       $MNT_P2
sudo chmod 755         $MNT_P2/setup.sh

sudo mv /mnt/usb2/etc/resolv.conf    $MNT_P2/etc/resolv.conf.org
sudo cp /etc/resolv.conf             $MNT_P2/etc
sudo cp /usr/bin/qemu-aarch64-static $MNT_P2/usr/bin

sudo chroot $MNT_P2 ./setup.sh

sudo mv $MNT_P2/etc/resolv.conf.org /mnt/usb2/etc/resolv.conf
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

sudo rmdir $MNT_P1
sudo rmdir $MNT_P2
