#!/usr/bin/env bash
#
# Build the bouquet kernel (one image for tulip and whyred) the same way the
# ROM does: device/xiaomi/bouquet/BoardConfig.mk + vendor/lineage kernel.mk.
#
#   TARGET_KERNEL_CLANG_VERSION := r596125
#   TARGET_KERNEL_CONFIG        := vendor/xiaomi/sdm660_defconfig + <device>.config
#   BOARD_KERNEL_IMAGE_NAME     := Image.gz-dtb
#   TARGET_DTB_LIST_WILDCARD    := vendor/qcom/*-<device>
#   KERNEL_MAKE_FLAGS           := LLVM=1 LLVM_IAS=1 CC=clang LD=ld.lld
#                                  CLANG_TRIPLE=aarch64-linux-gnu-
#                                  TARGET_BOARD_PLATFORM=sdm660
#
# Env:
#   CLANG_DIR  clang toolchain directory (required): the ROM uses
#              clang-r596125, CI uses the latest Neutron clang
#   OUT        kernel object dir (default: <kernel>/out)
#   DIST       where Image.gz-dtb and dtb end up (default: $OUT/dist)
#   JOBS       parallel jobs (default: nproc)

set -euo pipefail

KERNEL_DIR=$(cd "$(dirname "$0")/../.." && pwd)
: "${CLANG_DIR:?set CLANG_DIR to the clang toolchain directory}"
OUT=$(realpath -m "${OUT:-$KERNEL_DIR/out}")
DIST=$(realpath -m "${DIST:-$OUT/dist}")
JOBS=${JOBS:-$(nproc)}

# Same order as device/xiaomi/bouquet/devices/variants.inc
DEVICES=(tulip whyred)
CONFIG_DIR=$KERNEL_DIR/arch/arm64/configs/vendor/xiaomi

export PATH="$CLANG_DIR/bin:$PATH"
export LD_LIBRARY_PATH="$CLANG_DIR/lib64:$CLANG_DIR/lib:${LD_LIBRARY_PATH:-}"

MAKE=(make -C "$KERNEL_DIR" O="$OUT" -j"$JOBS"
	ARCH=arm64
	LLVM=1 LLVM_IAS=1
	CC=clang LD=ld.lld
	CLANG_TRIPLE=aarch64-linux-gnu-
	TARGET_BOARD_PLATFORM=sdm660
	KBUILD_BUILD_USER="${KBUILD_BUILD_USER:-build-user}"
	KBUILD_BUILD_HOST="${KBUILD_BUILD_HOST:-build-host}")

clang --version | head -n 1
mkdir -p "$OUT" "$DIST"

# .config: defconfig, then each device fragment merged in turn
# (make-kernel-config in vendor/lineage/build/tasks/kernel.mk)
cp "$CONFIG_DIR/sdm660_defconfig" "$OUT/.config"
"${MAKE[@]}" olddefconfig
for dev in "${DEVICES[@]}"; do
	(cd "$OUT" && "$KERNEL_DIR/scripts/kconfig/merge_config.sh" -m -O "$OUT" \
		"$OUT/.config" "$CONFIG_DIR/$dev.config")
	"${MAKE[@]}" olddefconfig
done

# Fail early if Kconfig dropped KernelSU / SUSFS
for opt in CONFIG_KSU CONFIG_KSU_SUSFS; do
	grep -q "^$opt=y" "$OUT/.config" || { echo "error: $opt not enabled" >&2; exit 1; }
done

"${MAKE[@]}" Image.gz-dtb dtbs

cp "$OUT/arch/arm64/boot/Image.gz-dtb" "$DIST/Image.gz-dtb"

# dtb for the boot image dtb section, same as the ROM's dtb.img
rm -f "$DIST/dtb"
for dev in "${DEVICES[@]}"; do
	mapfile -t dtbs < <(find "$OUT/arch/arm64/boot/dts/vendor/qcom" -maxdepth 1 \
		-type f -name "*-$dev.dtb" | sort)
	[ ${#dtbs[@]} -gt 0 ] || { echo "error: no dtb for $dev" >&2; exit 1; }
	cat "${dtbs[@]}" >> "$DIST/dtb"
done

cp "$OUT/include/config/kernel.release" "$DIST/version.txt"
echo "Kernel: $(cat "$DIST/version.txt")"
ls -l "$DIST"
