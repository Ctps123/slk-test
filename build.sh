#!/bin/bash
#
# Copyright (C) 2020-2021 Adithya R.

SECONDS=0 # builtin bash timer
ZIPNAME="SCORPION-TOPAZ-$(date '+%Y%m%d-%H%M').zip"
TC_DIR="$(pwd)/tc/clang-r450784e"
AK3_DIR="$(pwd)/android/AnyKernel3"
DEFCONFIG="vendor/alioth_defconfig"

export PATH="$TC_DIR/bin:$PATH"

if ! [ -d "$TC_DIR" ]; then
	echo "AOSP clang not found! Cloning to $TC_DIR..."
	if ! git clone --depth=1 -b 17 https://gitlab.com/ThankYouMario/android_prebuilts_clang-standalone "$TC_DIR"; then
		echo "Cloning failed! Aborting..."
		exit 1
	fi
fi

read -p "Do you want to use KernelSU? (y/n): " RESPONSE1
read -p "Do you want to upload to TELEGRAM? (y/n): " RESPONSE2

if [ "$RESPONSE1" == "y" ]; then
    curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -
    sed -i 's/# CONFIG_KSU is not set/CONFIG_KSU=y/' arch/arm64/configs/$DEFCONFIG
        echo "KernelSU Enabled!"
    else
        echo "KernelSU Disabled!"
fi

mkdir -p out
make O=out ARCH=arm64 $DEFCONFIG

echo -e "\nStarting compilation...\n"
make -j$(nproc --all) O=out ARCH=arm64 CC=clang LD=ld.lld AS=llvm-as AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi- LLVM=1 LLVM_IAS=1 Image dtbo.img

dts="out/arch/arm64/boot/dts/vendor/qcom"
build="out/arch/arm64/boot"

find $dts -name '*.dtb' -exec cat {} + >$build/dtb

kernel="out/arch/arm64/boot/Image"
dtb="out/arch/arm64/boot/dtb"
dtbo="out/arch/arm64/boot/dtbo.img"

if [ -f "$kernel" ] && [ -f "$dtb" ] && [ -f "$dtbo" ]; then
	echo -e "\nKernel compiled succesfully! Zipping up...\n"
	if [ -d "$AK3_DIR" ]; then
		cp -r $AK3_DIR AnyKernel3
	elif ! git clone -q git@github.com:SHAND-stuffs/AnyKernel3 -b alioth; then
		echo -e "\nAnyKernel3 repo not found locally and couldn't clone from GitHub! Aborting..."
		exit 1
	fi
        mkdir -p AnyKernel3/kernels/aospa
	cp $kernel $dtb $dtbo AnyKernel3/kernels/aospa
	rm -rf out/arch/arm64/boot
	cd AnyKernel3
	git checkout alioth &> /dev/null
	zip -r9 "../$ZIPNAME" * -x .git README.md *placeholder
	cd ..
	rm -rf AnyKernel3 out KernelSU
	git restore arch/arm64/configs/$DEFCONFIG drivers/Kconfig
	echo -e "\nCompleted in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s) !"
	echo "Zip: $ZIPNAME"
else
	echo -e "\nCompilation failed!"
	exit 1
fi

if [ "$RESPONSE2" == "y" ]; then
    if [ -d "upload" ]; then
        chmod +x upload/upload.sh
        ./upload/upload.sh
	rm SCORPION-TOPAZ-*.zip
else
        git clone -b alioth git@github.com:SHAND-stuffs/upload-telegram.git upload
        chmod +x upload/upload.sh
        ./upload/upload.sh
	rm SCORPION-TOPAZ-*.zip
    fi
fi
