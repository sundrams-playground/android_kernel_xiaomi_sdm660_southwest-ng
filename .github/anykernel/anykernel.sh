### AnyKernel3 Ramdisk Mod Script
## osm0sis @ xda-developers

### AnyKernel setup
# global properties
properties() { '
kernel.string=SouthWest-NG BakaSU + SUSFS for Redmi Note 6 Pro / Note 5 Pro
do.devicecheck=1
do.modules=0
do.systemless=0
do.cleanup=1
do.cleanuponabort=0
device.name1=tulip
device.name2=twolip
device.name3=whyred
device.name4=bouquet
device.name5=
supported.versions=
supported.patchlevels=
supported.vendorpatchlevels=
'; } # end properties


### AnyKernel install
## boot shell variables
BLOCK=/dev/block/bootdevice/by-name/boot;
IS_SLOT_DEVICE=0;
RAMDISK_COMPRESSION=auto;
PATCH_VBMETA_FLAG=auto;

# import functions/variables and setup patching - see for reference (DO NOT REMOVE)
. tools/ak3-core.sh;

# One kernel for both devices: the board code is picked at runtime from
# androidboot.hwdevice and the bootloader picks the DTB by board-id, so the
# Image.gz-dtb and dtb (tulip + whyred) in this zip are used as they are.
# The ramdisk and cmdline of the installed boot image are kept.

# boot install
split_boot; # skip ramdisk unpack, only swap kernel (and dtb if the image has one)

flash_boot;
## end boot install
