#!/bin/bash
#
# help:
# BUSYBOX=path/to/busybox LINUX=path/to/linux LOWRISC=path/to/lowrisc make_root.sh

if [ -z "$BUSYBOX" ]; then BUSYBOX=$TOP/riscv-tools/busybox-1.21.1; fi
BUSYBOX_CFG=$TOP/riscv-tools/busybox_config.fpga

ROOT_INITTAB=$TOP/riscv-tools/inittab

LINUX=$TOP/riscv-tools/linux-4.6.2

# use nexys4 dev_map.h by default
if [ -z "$FPGA_BOARD" ]; then LOWRISC=$TOP/fpga/board/nexys4_ddr
else LOWRISC=$TOP/fpga/board/$FPGA_BOARD; fi


CDIR=$PWD

if [ -d "$BUSYBOX" ] && [ -d "$LINUX" ]; then
    echo "build busybox..."
    cp -p $BUSYBOX_CFG "$BUSYBOX"/.config &&
    make -j$(nproc) -C "$BUSYBOX" 2>&1 1>/dev/null &&
    if [ -d ramfs ]; then rm -fr ramfs; fi &&
    mkdir ramfs && cd ramfs &&
    mkdir -p bin etc dev home lib proc sbin sys tmp usr mnt nfs root usr/bin usr/lib usr/sbin &&
#    cp "$BUSYBOX"/busybox bin/ &&
#    ln -s bin/busybox ./init &&
#    cp $ROOT_INITTAB etc/inittab &&
    cp "$BUSYBOX"/busybox bin/ &&
    cp $TOP/riscv-tools/initial_$1 init &&
    chmod +x init &&
    echo "\
        mknod dev/null c 1 3 && \
        mknod dev/tty c 5 0 && \
        mknod dev/zero c 1 5 && \
        mknod dev/console c 5 1 && \
        mknod dev/mmcblk0 b 179 0 && \
        mknod dev/mmcblk0p1 b 179 1 && \
        mknod dev/mmcblk0p2 b 179 2 && \
        find . | cpio -H newc -o > "$LINUX"/initramfs.cpio\
        " | fakeroot &&
    if [ $? -ne 0 ]; then echo "build busybox failed!"; fi &&
    \
    make -j$(nproc) -C "$LINUX" ARCH=riscv vmlinux &&
    if [ $? -ne 0 ]; then echo "build linux failed!"; fi &&
    \
    echo "build bbl..." &&
    if [ ! -d $TOP/fpga/bootloader/build ]; then
        mkdir -p $TOP/fpga/bootloader/build
    fi   &&
    cd $TOP/fpga/bootloader/build &&
    ../configure \
        --host=riscv64-unknown-elf \
        --with-lowrisc="$LOWRISC" \
        --with-payload="$LINUX"/vmlinux \
        2>&1 1>/dev/null &&
    make -j$(nproc) bbl &&
    if [ $? -ne 0 ]; then echo "build linux failed!"; fi &&
    \
    cd "$CDIR"
    cp $TOP/fpga/bootloader/build/bbl ./boot.bin
else
    echo "make sure you have both linux and busybox downloaded."
    echo "usage:  [BUSYBOX=path/to/busybox] [LINUX=path/to/linux] [LOWRISC=path/to/lowrisc] make_root.sh"
fi
