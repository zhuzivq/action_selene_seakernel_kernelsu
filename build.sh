#!/usr/bin/env bash
#
# GNU General Public License v3.0
# Copyright (C) 2023 MoChenYa mochenya20070702@gmail.com
#

WORKDIR="$(pwd)"

# ZyClang
ZYCLANG_DLINK="https://github.com/ZyCromerZ/Clang/releases/download/18.0.0-20231010-release/Clang-18.0.0-20231010.tar.gz"
ZYCLANG_DIR="$WORKDIR/ZyClang/bin"

# Kernel Source
KERNEL_GIT="https://github.com/zhuzivq/Sea_Kernel-Selene.git"
KERNEL_BRANCHE="twelve-test"
KERNEL_DIR="$WORKDIR/SeaKernel"
SEA_KERNEL_VERSION="Alina"
SEA_KERNEL_CODENAME="8.5/Alina🧜✨"
SEA_KERNEL_CODENAME_ESCAPE="8.5\/Alina🧜✨"

# rwProcMem
RWPROCMEM_GIT="https://github.com/zhuzivq/rwProcKernelmodules.git"
RWPROCMEM_BRANCHE="main"

# Anykernel3
ANYKERNEL3_GIT="https://github.com/Kentanglu/AnyKernel3.git"
ANYKERNEL3_BRANCHE="selene-old"

# Magiskboot
MAGISKBOOT_DLINK="https://github.com/xiaoxindada/magiskboot_ndk_on_linux/releases/download/Magiskboot-26301-48/magiskboot.7z"
MAGISKBOOT="$WORKDIR/magiskboot/magiskboot"
ORIGIN_BOOTIMG_DLINK="https://github.com/zhuzivq/action_selene_seakernel_kernelsu/releases/download/originimg/boot.img"

# Build
DEVICES_CODE="selene"
DEVICE_DEFCONFIG="selene_tiramisu_defconfig"
DEVICE_DEFCONFIG_FILE="$KERNEL_DIR/arch/arm64/configs/$DEVICE_DEFCONFIG"
IMAGE="$KERNEL_DIR/out/arch/arm64/boot/Image.gz-dtb"
DTB="$KERNEL_DIR/out/arch/arm64/boot/dts/mediatek/mt6768.dtb"
DTBO="$KERNEL_DIR/out/arch/arm64/boot/dtbo.img"

export KBUILD_BUILD_USER=MoChenYa
export KBUILD_BUILD_HOST=GitHubCI

msg() {
	echo
	echo -e "\e[1;32m$*\e[0m"
	echo
}

cd $WORKDIR

# Download ZyClang
msg " • 🌸 Work on $WORKDIR 🌸"
msg " • 🌸 Cloning Toolchain 🌸 "
msg " • 🌸 Donwload $ZYCLANG_DLINK 🌸 "
mkdir -p ZyClang
aria2c -s16 -x16 -k1M $ZYCLANG_DLINK -o ZyClang.tar.gz
tar -C ZyClang/ -zxvf ZyClang.tar.gz
rm -rf ZyClang.tar.gz

# CLANG LLVM VERSIONS
CLANG_VERSION="$($ZYCLANG_DIR/clang --version | head -n 1)"
LLD_VERSION="$($ZYCLANG_DIR/ld.lld --version | head -n 1)"

msg " • 🌸 Cloning Kernel Source 🌸 "
git clone --depth=1 $KERNEL_GIT -b $KERNEL_BRANCHE $KERNEL_DIR
cd $KERNEL_DIR
KERNEL_HEAD_HASH=$(git log --pretty=format:'%H' -1)

msg " • 🌸 Patching KernelSU 🌸 "
curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -
KSU_GIT_VERSION=$(cd KernelSU && git rev-list --count HEAD)
KERNELSU_VERSION=$(($KSU_GIT_VERSION + 10000 + 200))
msg " • 🌸 KernelSU version: $KERNELSU_VERSION 🌸 "

# PATCH KERNELSU
msg " • 🌸 Applying patches 🌸 "

apply_patchs () {
for patch_file in $WORKDIR/patchs/*.patch
	do
	patch -p1 < "$patch_file"
done
}
apply_patchs

sed -i "/CONFIG_LOCALVERSION=\"/s/.$/$SEA_KERNEL_CODENAME_ESCAPE-KSU-$KERNELSU_VERSION\"/" $DEVICE_DEFCONFIG_FILE
msg " • 🌸 $(grep 'CONFIG_LOCALVERSION=' $DEVICE_DEFCONFIG_FILE) 🌸 "

sed -i "/CONFIG_LOCALVERSION=\"/s/.$/-KSU-$KERNELSU_VERSION\"/" $DEVICE_DEFCONFIG_FILE
cd $KERNEL_DIR/drivers && git clone -b $RWPROCMEM_BRANCHE $RWPROCMEM_GIT
sed -i '1i obj-y += rwProcKernelmodules/' $KERNEL_DIR/drivers/Makefile
cd $KERNEL_DIR

# BUILD KERNEL
msg " • 🌸 Started Compilation 🌸 "

mkdir -p $WORKDIR/out

args="PATH=$ZYCLANG_DIR:$PATH \
ARCH=arm64 \
SUBARCH=arm64 \
CROSS_COMPILE=aarch64-linux-gnu- \
CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
CC=clang \
NM=llvm-nm \
CXX=clang++ \
AR=llvm-ar \
LD=ld.lld \
STRIP=llvm-strip \
OBJCOPY=llvm-objcopy \
OBJDUMP=llvm-objdump \
OBJSIZE=llvm-size \
READELF=llvm-readelf \
HOSTAR=llvm-ar \
HOSTLD=ld.lld \
HOSTCC=clang \
HOSTCXX=clang++ \
LLVM=1"

# LINUX KERNEL VERSION
rm -rf out
make O=out $args $DEVICE_DEFCONFIG
KERNEL_VERSION=$(make O=out $args kernelversion | grep "4.14")
msg " • 🌸 LINUX KERNEL VERSION : $KERNEL_VERSION 🌸 "
make O=out $args -j"$(nproc --all)" | tee "$WORKDIR/out/Build.log"

msg " • 🌸 Checking builds 🌸 "
if [ ! -e $IMAGE ]; then
    echo -e " • 🌸 \033[31mBuild Failed!\033[0m"
    exit 1
fi

msg " • 🌸 Packing Kernel 🌸 "
cd $WORKDIR
git clone --depth=1 $ANYKERNEL3_GIT -b $ANYKERNEL3_BRANCHE $WORKDIR/Anykernel3
cd $WORKDIR/Anykernel3
cp $IMAGE .
cp $DTB $WORKDIR/Anykernel3/dtb
cp $DTBO .
echo "• Within KernelSU $KERNELSU_VERSION !!!" >> $WORKDIR/Anykernel3/banner

# PACK FILE
time=$(TZ='Asia/Shanghai' date +"%Y-%m-%d %H:%M:%S")
shanghai_time=$(TZ='Asia/Shanghai' date +%Y%m%d%H)
ZIP_NAME="KernelSU-$KERNELSU_VERSION-ROSS-selene-$KERNEL_VERSION-Sea-$SEA_KERNEL_VERSION-$shanghai_time-GithubCI"
find ./ * -exec touch -m -d "$time" {} \;
zip -r9 $ZIP_NAME.zip *
cp *.zip $WORKDIR/out && cp $DTBO $WORKDIR/out

# Packed Image
# Setup magiskboot
cd $WORKDIR && mkdir magiskboot
aria2c -s16 -x16 -k1M $MAGISKBOOT_DLINK -o magiskboot.7z
7z e magiskboot.7z out/x86_64/magiskboot -omagiskboot/
rm -rf magiskboot.7z

# Download original boot.img
aria2c -s16 -x16 -k1M $ORIGIN_BOOTIMG_DLINK -o magiskboot/boot.img
cd $WORKDIR/magiskboot

# Packing
$MAGISKBOOT unpack -h boot.img
cp $IMAGE ./Image.gz-dtb
$MAGISKBOOT split Image.gz-dtb
cp $DTB ./dtb
$MAGISKBOOT repack boot.img
mv new-boot.img $WORKDIR/out/$ZIP_NAME.img
# SElinux Permissive
sed -i '/cmdline=/ s/$/ androidboot.selinux=permissive/' header
$MAGISKBOOT repack boot.img
mv new-boot.img $WORKDIR/out/$ZIP_NAME-Permissive.img

cd $WORKDIR/out
echo "
### SEA KERNEL WITH KERNELSU
- 🌊 **Build Time** : $(TZ='Asia/Shanghai' date +"%Y-%m-%d %H:%M:%S") # ShangHai TIME
- 🌊 **Device Code** : $DEVICES_CODE
- 🌊 **Sea Kernel Codename** : R¹.$SEA_KERNEL_CODENAME
- 🌊 **Linux Version** : $KERNEL_VERSION
- 🌊 **KernelSU Version**: $KERNELSU_VERSION
- 🌊 **Clang Version**: $CLANG_VERSION
- 🌊 **LLD Version**: $LLD_VERSION
- 🌊 **Anykernel3**: $ZIP_NAME.zip
- 🌊 **Anykernel3 MD5**: $(md5sum $ZIP_NAME.zip | awk '{print $1}')
- 🌊 **Image**: $ZIP_NAME.img
- 🌊 **Image MD5** $(md5sum $ZIP_NAME.img | awk '{print $1}')
- 🌊 **Image(Permissive)**: $ZIP_NAME-Permissive.img
- 🌊 **Image(Permissive) MD5**: $(md5sum $ZIP_NAME-Permissive.img | awk '{print $1}')
" > RELEASE.md
echo "$KERNELSU_VERSION" > KSU_VERSION.txt
echo "$KERNEL_VERSION" > KERNEL_VERSION.txt
echo "$KERNEL_HEAD_HASH" > KERNEL_HEAD_HASH.txt
cat RELEASE.md
cat KSU_VERSION.txt
cat KERNEL_VERSION.txt
cat KERNEL_HEAD_HASH.txt
msg "• 🌸 Done! 🌸 "
