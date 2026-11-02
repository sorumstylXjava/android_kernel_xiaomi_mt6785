# GhostKernel Build System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build script `b.sh` yang compile kernel GhostKernel untuk Redmi Note 10S (rosemary), apply BakaSU root + manual hook + ZRAM multicomp + SLMK patches, optimasi defconfig untuk multitasking & gaming ML, dan pack output jadi flashable zip via AnyKernel3.

**Architecture:** Script `b.sh` mengorkestrasi seluruh pipeline: setup BakaSU (sekali saja via flag), apply patches, compile dengan Clang r416183b pure LLVM, lalu pack Image.gz-dtb ke AnyKernel3 zip.

**Tech Stack:** Bash, Clang r416183b, LLVM tools, AnyKernel3, BakaSU/KernelSU, patch(1)

**Spec:** `AGENTS.md` + device tree analysis dari `sorumstylXjava/device_xiaomi_rosemary`

## Global Constraints

- Kernel: Linux 4.19.x CIP/ST, defconfig: `arch/arm64/configs/rosemary_defconfig`
- Toolchain: `/home/java/toolchain/clang-r416183b` — pure Clang, LLVM=1, LLVM_IAS=1
- Output: `arch/arm64/boot/Image.gz-dtb` saja
- AnyKernel: branch `rosemary` dari `github.com/sorumstylXjava/AnyKernel`
- Root: BakaSU via `kernel/setup.sh`, hook mode: `CONFIG_KSU_MANUAL_HOOK=y`
- Manual hook patch: `resuki-4.19-cip-st.patch` dari `xxblebleblexx/manual_hook_fix`
- ZRAM patch: `zram_multicomp_4.19_consolidated.patch` (ada di `/home/java/Downloads/`)
- SLMK patch: `slmk-4.19-cip-st.patch` (ada di `/home/java/Downloads/`)
- Kernel name: GhostKernel

## Review Focus

- BakaSU setup.sh harus dipanggil hanya sekali (cek symlink `drivers/kernelsu` sebelum clone ulang)
- Patches harus idempotent: cek apakah sudah diapply sebelum apply ulang
- AnyKernel clone harus bersih setiap build (hapus folder lama)
- Build error harus langsung abort script dengan pesan jelas
- ZRAM multicomp depends on `CONFIG_ZRAM=y` dan `CONFIG_CRYPTO_ZSTD=y` — harus ada di defconfig

---

## Task 1: Apply patches ke defconfig (optimasi + KSU + ZRAM + SLMK)

**Files:**
- Modify: `arch/arm64/configs/rosemary_defconfig`

**Steps:**

- [ ] Tambahkan config berikut ke `rosemary_defconfig` (append di akhir file):

```
# --- GhostKernel: BakaSU / KernelSU ---
CONFIG_KSU=y
CONFIG_KSU_MANUAL_HOOK=y

# --- GhostKernel: ZRAM + Multi-comp ---
CONFIG_ZRAM=y
CONFIG_ZRAM_MULTI_COMP=y
CONFIG_ZRAM_DEF_RECOMP_ZSTD=y
CONFIG_ZRAM_MEMORY_TRACKING=y
CONFIG_CRYPTO_LZ4=y
CONFIG_CRYPTO_LZ4HC=y
CONFIG_CRYPTO_ZSTD=y
CONFIG_CRYPTO_LZO=y

# --- GhostKernel: Simple LMK ---
CONFIG_ANDROID_SIMPLE_LMK=y
CONFIG_ANDROID_SIMPLE_LMK_MINFREE=128
CONFIG_ANDROID_SIMPLE_LMK_TIMEOUT_MSEC=200

# --- GhostKernel: Scheduler / EAS ---
CONFIG_UCLAMP_TASK=y
CONFIG_UCLAMP_TASK_GROUP=y
CONFIG_SCHED_WALT=y

# --- GhostKernel: Network (TCP BBR) ---
CONFIG_TCP_CONG_BBR=y
CONFIG_NET_SCH_FQ=y
CONFIG_DEFAULT_TCP_CONG="bbr"

# --- GhostKernel: Misc perf ---
CONFIG_HZ_300=y
CONFIG_TRANSPARENT_HUGEPAGE=y
CONFIG_TRANSPARENT_HUGEPAGE_MADVISE=y
CONFIG_LZ4_COMPRESS=y
CONFIG_LZ4_DECOMPRESS=y
CONFIG_ZSTD_COMPRESS=y
CONFIG_ZSTD_DECOMPRESS=y

# --- GhostKernel: Disable debug overhead ---
# CONFIG_DEBUG_INFO is not set
# CONFIG_KFENCE is not set
```

- [ ] Verify file tidak kosong: `wc -l arch/arm64/configs/rosemary_defconfig`

---

## Task 2: Download dan apply kernel patches

**Files:**
- Source: `/home/java/Downloads/zram_multicomp_4.19_consolidated.patch`
- Source: `/home/java/Downloads/slmk-4.19-cip-st.patch`
- Download: `resuki-4.19-cip-st.patch` dari `github.com/xxblebleblexx/manual_hook_fix`

**Steps:**

- [ ] Download manual hook patch:
```bash
curl -LSs "https://raw.githubusercontent.com/xxblebleblexx/manual_hook_fix/main/resuki-4.19-cip-st.patch" -o /tmp/resuki-4.19-cip-st.patch
```

- [ ] Apply ZRAM multicomp patch (cek dulu apakah sudah diapply):
```bash
if ! git -C /home/java/Kernel apply --check /home/java/Downloads/zram_multicomp_4.19_consolidated.patch 2>/dev/null; then
    echo "[INFO] ZRAM patch already applied or conflicts, skipping"
else
    git -C /home/java/Kernel apply /home/java/Downloads/zram_multicomp_4.19_consolidated.patch
fi
```

- [ ] Apply SLMK patch (same check):
```bash
if ! git -C /home/java/Kernel apply --check /home/java/Downloads/slmk-4.19-cip-st.patch 2>/dev/null; then
    echo "[INFO] SLMK patch already applied or conflicts, skipping"
else
    git -C /home/java/Kernel apply /home/java/Downloads/slmk-4.19-cip-st.patch
fi
```

- [ ] Apply manual hook patch (same check):
```bash
if ! git -C /home/java/Kernel apply --check /tmp/resuki-4.19-cip-st.patch 2>/dev/null; then
    echo "[INFO] Manual hook patch already applied or conflicts, skipping"
else
    git -C /home/java/Kernel apply /tmp/resuki-4.19-cip-st.patch
fi
```

---

## Task 3: Setup BakaSU (sekali saja)

**Files:**
- Create: `drivers/kernelsu` symlink → `KernelSU/kernel`
- Modify: `drivers/Makefile`, `drivers/Kconfig` (by setup.sh)

**Steps:**

- [ ] Jalankan BakaSU setup (hanya jika belum ada):
```bash
if [ ! -L /home/java/Kernel/drivers/kernelsu ]; then
    cd /home/java/Kernel
    curl -LSs "https://raw.githubusercontent.com/Baka-SU/BakaSU/main/kernel/setup.sh" | bash -
fi
```

- [ ] Verify symlink ada: `ls -la /home/java/Kernel/drivers/kernelsu`

---

## Task 4: Buat `b.sh` — build script utama

**Files:**
- Create: `/home/java/Kernel/b.sh`

**Steps:**

- [ ] Tulis `b.sh` dengan struktur berikut:

```bash
#!/usr/bin/env bash
# GhostKernel Build Script
# Device: Redmi Note 10S (rosemary) — MT6785
# Kernel: Linux 4.19.x CIP/ST

set -e

# ============================================================
# CONFIG
# ============================================================
KERNEL_DIR="$(cd "$(dirname "$0")"; pwd)"
TOOLCHAIN_DIR="/home/java/toolchain"
CLANG_DIR="${TOOLCHAIN_DIR}/clang-r416183b"
DEFCONFIG="rosemary_defconfig"
KERNEL_NAME="GhostKernel"
CORES=$(nproc --all)

OUT_DIR="${KERNEL_DIR}/out"
AK3_DIR="${KERNEL_DIR}/AnyKernel3"
PATCH_DIR="/home/java/Downloads"
ZRAM_PATCH="${PATCH_DIR}/zram_multicomp_4.19_consolidated.patch"
SLMK_PATCH="${PATCH_DIR}/slmk-4.19-cip-st.patch"
HOOK_PATCH_URL="https://raw.githubusercontent.com/xxblebleblexx/manual_hook_fix/main/resuki-4.19-cip-st.patch"
HOOK_PATCH="/tmp/resuki-4.19-cip-st.patch"
BAKAS_SETUP_URL="https://raw.githubusercontent.com/Baka-SU/BakaSU/main/kernel/setup.sh"
AK3_REPO="https://github.com/sorumstylXjava/AnyKernel"
AK3_BRANCH="rosemary"

# ============================================================
# COLORS
# ============================================================
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

log()  { echo -e "${CYAN}[GhostKernel]${NC} $*"; }
ok()   { echo -e "${GREEN}[✓]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[✗]${NC} $*"; exit 1; }

# ============================================================
# FUNCTIONS
# ============================================================

apply_patch() {
    local patch="$1"
    local name="$2"
    if git -C "${KERNEL_DIR}" apply --check "${patch}" 2>/dev/null; then
        log "Applying ${name}..."
        git -C "${KERNEL_DIR}" apply "${patch}" && ok "${name} applied"
    else
        warn "${name} already applied or has conflicts — skipping"
    fi
}

setup_bakasu() {
    if [ ! -L "${KERNEL_DIR}/drivers/kernelsu" ]; then
        log "Setting up BakaSU..."
        cd "${KERNEL_DIR}"
        curl -LSs "${BAKAS_SETUP_URL}" | bash -
        ok "BakaSU setup complete"
    else
        ok "BakaSU already set up"
    fi
}

setup_anykernel() {
    log "Cloning AnyKernel3 (branch: ${AK3_BRANCH})..."
    rm -rf "${AK3_DIR}"
    git clone --depth=1 -b "${AK3_BRANCH}" "${AK3_REPO}" "${AK3_DIR}"
    ok "AnyKernel3 ready"
}

# ============================================================
# PARSE ARGS
# ============================================================
SETUP_ONLY=0
CLEAN=0
for arg in "$@"; do
    case "$arg" in
        --setup)  SETUP_ONLY=1 ;;
        --clean)  CLEAN=1 ;;
        --help|-h)
            echo -e "${BOLD}GhostKernel Build Script${NC}"
            echo "  ./b.sh           — full build"
            echo "  ./b.sh --setup   — apply patches & setup BakaSU only"
            echo "  ./b.sh --clean   — clean out/ dir"
            exit 0 ;;
    esac
done

# ============================================================
# MAIN
# ============================================================

echo -e "${BOLD}"
echo "  ██████╗ ██╗  ██╗ ██████╗ ███████╗████████╗"
echo "  ██╔════╝ ██║  ██║██╔═══██╗██╔════╝╚══██╔══╝"
echo "  ██║  ███╗███████║██║   ██║███████╗   ██║   "
echo "  ██║   ██║██╔══██║██║   ██║╚════██║   ██║   "
echo "  ╚██████╔╝██║  ██║╚██████╔╝███████║   ██║   "
echo "   ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝   ╚═╝   "
echo "  KERNEL — Redmi Note 10S (rosemary) — MT6785"
echo -e "${NC}"

cd "${KERNEL_DIR}"

# --- Clean ---
if [ "${CLEAN}" -eq 1 ]; then
    log "Cleaning out/..."
    rm -rf "${OUT_DIR}"
    ok "Clean done"
    exit 0
fi

# --- Patch & BakaSU setup ---
log "Step 1: Applying patches..."
curl -LSs "${HOOK_PATCH_URL}" -o "${HOOK_PATCH}" 2>/dev/null || warn "Could not download hook patch"
[ -f "${ZRAM_PATCH}" ] && apply_patch "${ZRAM_PATCH}" "ZRAM multicomp" || warn "ZRAM patch not found at ${ZRAM_PATCH}"
[ -f "${SLMK_PATCH}" ] && apply_patch "${SLMK_PATCH}" "Simple LMK" || warn "SLMK patch not found at ${SLMK_PATCH}"
[ -f "${HOOK_PATCH}" ] && apply_patch "${HOOK_PATCH}" "Manual Hook (BakaSU)" || warn "Hook patch download failed"

log "Step 2: Setup BakaSU..."
setup_bakasu

[ "${SETUP_ONLY}" -eq 1 ] && { ok "Setup-only done. Exiting."; exit 0; }

# --- Build ---
log "Step 3: Building kernel with ${CORES} cores..."
mkdir -p "${OUT_DIR}"

BUILD_START=$(date +"%s")

make -C "${KERNEL_DIR}" \
    O="${OUT_DIR}" \
    ARCH=arm64 \
    CC="${CLANG_DIR}/bin/clang" \
    LD="${CLANG_DIR}/bin/ld.lld" \
    AR="${CLANG_DIR}/bin/llvm-ar" \
    NM="${CLANG_DIR}/bin/llvm-nm" \
    OBJCOPY="${CLANG_DIR}/bin/llvm-objcopy" \
    OBJDUMP="${CLANG_DIR}/bin/llvm-objdump" \
    READELF="${CLANG_DIR}/bin/llvm-readelf" \
    STRIP="${CLANG_DIR}/bin/llvm-strip" \
    CROSS_COMPILE="aarch64-linux-gnu-" \
    CROSS_COMPILE_ARM32="arm-linux-gnueabi-" \
    LLVM=1 \
    LLVM_IAS=1 \
    LOCALVERSION="-${KERNEL_NAME}" \
    -j"${CORES}" \
    "${DEFCONFIG}" 2>&1 | tail -3

make -C "${KERNEL_DIR}" \
    O="${OUT_DIR}" \
    ARCH=arm64 \
    CC="${CLANG_DIR}/bin/clang" \
    LD="${CLANG_DIR}/bin/ld.lld" \
    AR="${CLANG_DIR}/bin/llvm-ar" \
    NM="${CLANG_DIR}/bin/llvm-nm" \
    OBJCOPY="${CLANG_DIR}/bin/llvm-objcopy" \
    OBJDUMP="${CLANG_DIR}/bin/llvm-objdump" \
    READELF="${CLANG_DIR}/bin/llvm-readelf" \
    STRIP="${CLANG_DIR}/bin/llvm-strip" \
    CROSS_COMPILE="aarch64-linux-gnu-" \
    CROSS_COMPILE_ARM32="arm-linux-gnueabi-" \
    LLVM=1 \
    LLVM_IAS=1 \
    LOCALVERSION="-${KERNEL_NAME}" \
    -j"${CORES}" 2>&1 || err "Build failed!"

BUILD_END=$(date +"%s")
BUILD_DIFF=$((BUILD_END - BUILD_START))

# --- Check output ---
IMAGE="${OUT_DIR}/arch/arm64/boot/Image.gz-dtb"
[ -f "${IMAGE}" ] || err "Image.gz-dtb not found! Build may have failed."
ok "Build complete in $((BUILD_DIFF / 60))m $((BUILD_DIFF % 60))s"

# --- Pack with AnyKernel3 ---
log "Step 4: Packing with AnyKernel3..."
setup_anykernel
mkdir -p "${AK3_DIR}/kernels"
cp "${IMAGE}" "${AK3_DIR}/kernels/Image.gz-dtb"

DATE=$(date +"%Y%m%d-%H%M")
ZIP_NAME="${KERNEL_NAME}-rosemary-${DATE}.zip"
ZIP_OUT="${KERNEL_DIR}/${ZIP_NAME}"

cd "${AK3_DIR}"
zip -r9 "${ZIP_OUT}" . -x '*.git*' -x 'LICENSE' >/dev/null
cd "${KERNEL_DIR}"

ok "Flashable zip: ${ZIP_NAME}"
echo -e "\n${GREEN}${BOLD}══════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}  GhostKernel build DONE!${NC}"
echo -e "${CYAN}  File : ${ZIP_NAME}${NC}"
echo -e "${CYAN}  Size : $(du -sh "${ZIP_OUT}" | cut -f1)${NC}"
echo -e "${GREEN}${BOLD}══════════════════════════════════════════${NC}\n"
```

- [ ] Set executable: `chmod +x /home/java/Kernel/b.sh`

---

## Task 5: Update AGENTS.md dengan status

- [ ] Tambah section "Build Script" ke AGENTS.md
- [ ] Catat semua patches yang sudah diapply di AGENTS.md
