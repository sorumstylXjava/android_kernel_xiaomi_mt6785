#!/usr/bin/env bash
#
# GhostKernel Build Script
# Device : Redmi Note 10S (rosemary / secret / maltose) - MT6785
# Kernel : Linux 4.19.x CIP/ST
# Author : @Java_nih_deks
#

set -eo pipefail

# ============================================================
# COLORS & LOGGING
# ============================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

log()  { echo -e "${CYAN}[GhostKernel]${NC} $*"; }
ok()   { echo -e "${GREEN}[✓]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[✗]${NC} $*"; exit 1; }

# ============================================================
# DIRECTORIES & PATHS
# ============================================================
KERNEL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLCHAIN_DIR="/home/java/toolchain"
CLANG_DIR="${TOOLCHAIN_DIR}/clang-r416183b"
DEFCONFIG="rosemary_defconfig"
KERNEL_NAME="GhostKernel"
CORES=$(nproc --all)

OUT_DIR="${KERNEL_DIR}/out"
OUTPUT_DIR="${KERNEL_DIR}/output"
AK3_DIR="${KERNEL_DIR}/AnyKernel3"
AK3_REPO="https://github.com/sorumstylXjava/AnyKernel"
AK3_BRANCH="rosemary"

# Ensure custom tools (bc, zip, dtc) and clang are in PATH
export PATH="/home/java/.local/bin:${CLANG_DIR}/bin:${PATH}"

# Compiler flags and binaries
export ARCH="arm64"
export SUBARCH="arm64"
export CC="clang"
export LD="ld.lld"
export AR="llvm-ar"
export NM="llvm-nm"
export OBJCOPY="llvm-objcopy"
export OBJDUMP="llvm-objdump"
export READELF="llvm-readelf"
export STRIP="llvm-strip"
export CROSS_COMPILE="aarch64-linux-gnu-"
export CROSS_COMPILE_ARM32="arm-linux-gnueabi-"
export LLVM=1
export LLVM_IAS=1
export LOCALVERSION="-${KERNEL_NAME}-cip136"

# ============================================================
# HELP / CLI PARSING
# ============================================================
DO_CLEAN=0
DO_MENUCONFIG=0
DO_REGEN_DEFCONFIG=0
NO_ZIP=0

for arg in "$@"; do
    case "$arg" in
        --clean|-c)
            DO_CLEAN=1
            ;;
        --menuconfig|-m)
            DO_MENUCONFIG=1
            ;;
        --regen-defconfig|-r)
            DO_REGEN_DEFCONFIG=1
            ;;
        --no-zip)
            NO_ZIP=1
            ;;
        --help|-h)
            echo -e "${BOLD}${CYAN}GhostKernel Build Script Usage:${NC}"
            echo "  ./b.sh                   Build kernel & package AnyKernel3 flashable zip"
            echo "  ./b.sh --clean           Clean build artifacts (out/ and AnyKernel3/)"
            echo "  ./b.sh --menuconfig      Open interactive kernel menuconfig"
            echo "  ./b.sh --regen-defconfig Save current out/.config back to rosemary_defconfig"
            echo "  ./b.sh --no-zip          Compile kernel only without AnyKernel3 packing"
            exit 0
            ;;
        *)
            warn "Unknown option '$arg', continuing with standard build..."
            ;;
    esac
done

# ============================================================
# BANNER
# ============================================================
echo -e "${MAGENTA}${BOLD}"
cat << 'EOF'
   ____  __               __   __ __                      __ 
  / __ \/ /_  ____  _____/ /_ / //_/__  _________  ___   / / 
 / /_/ / __ \/ __ \/ ___/ __// ,< / _ \/ ___/ __ \/ _ \ / /  
/ /_/ / / / / /_/ (__  ) /_ / /| /  __/ /  / / / /  __// /   
\___\_\/_/ /_/\____/____/\__//_/ |_|\___/_/  /_/ /_/\___//_/    
EOF
echo -e "${CYAN}  Device   : Redmi Note 10S (rosemary / MT6785)"
echo -e "  Clang    : $(clang --version | head -n 1)"
echo -e "  Cores    : ${CORES}"
echo -e "  Root     : BakaSU + Manual Hook"
echo -e "  Target   : Image.gz-dtb"
echo -e "${NC}"

cd "${KERNEL_DIR}"

# ============================================================
# CLEAN OPERATION
# ============================================================
if [ "${DO_CLEAN}" -eq 1 ]; then
    log "Cleaning build outputs..."
    rm -rf "${OUT_DIR}" "${AK3_DIR}" "${OUTPUT_DIR}" "${KERNEL_DIR}"/GhostKernel-*.zip
    ok "Clean finished."
    exit 0
fi

# ============================================================
# DEFCONFIG & MAKE ARGS
# ============================================================
MAKE_ARGS=(
    O="${OUT_DIR}"
    ARCH="${ARCH}"
    SUBARCH="${SUBARCH}"
    CC="${CC}"
    LD="${LD}"
    AR="${AR}"
    NM="${NM}"
    OBJCOPY="${OBJCOPY}"
    OBJDUMP="${OBJDUMP}"
    READELF="${READELF}"
    STRIP="${STRIP}"
    CROSS_COMPILE="${CROSS_COMPILE}"
    CROSS_COMPILE_ARM32="${CROSS_COMPILE_ARM32}"
    LLVM="${LLVM}"
    LLVM_IAS="${LLVM_IAS}"
    LOCALVERSION="${LOCALVERSION}"
)

mkdir -p "${OUT_DIR}"
# Clean accidental in-tree generated files to prevent out-of-tree shadowing
rm -rf "${KERNEL_DIR}/arch/arm64/include/generated" "${KERNEL_DIR}/include/generated" "${KERNEL_DIR}/include/config"
# Ensure clean version string (4.19.325-GhostKernel-cip136) without random git hashes
touch "${KERNEL_DIR}/.scmversion"
rm -f "${KERNEL_DIR}/localversion-st" "${KERNEL_DIR}/localversion-cip"

if [ "${DO_MENUCONFIG}" -eq 1 ]; then
    log "Opening menuconfig..."
    if [ ! -f "${OUT_DIR}/.config" ]; then
        make "${MAKE_ARGS[@]}" "${DEFCONFIG}"
    fi
    make "${MAKE_ARGS[@]}" menuconfig
    exit 0
fi

if [ "${DO_REGEN_DEFCONFIG}" -eq 1 ]; then
    log "Regenerating ${DEFCONFIG} from ${OUT_DIR}/.config..."
    make "${MAKE_ARGS[@]}" savedefconfig
    cp "${OUT_DIR}/defconfig" "${KERNEL_DIR}/arch/arm64/configs/${DEFCONFIG}"
    ok "Saved to arch/arm64/configs/${DEFCONFIG}"
    exit 0
fi

# Generate .config if missing
if [ ! -f "${OUT_DIR}/.config" ]; then
    log "Generating config from ${DEFCONFIG}..."
    make "${MAKE_ARGS[@]}" "${DEFCONFIG}"
    ok "Config generated."
fi

# ============================================================
# COMPILATION
# ============================================================
log "Starting compilation with ${CORES} parallel jobs..."
START_TIME=$(date +%s)

make "${MAKE_ARGS[@]}" -j"${CORES}" Image.gz-dtb

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

IMAGE="${OUT_DIR}/arch/arm64/boot/Image.gz-dtb"
if [ ! -f "${IMAGE}" ]; then
    err "Kernel image not found at ${IMAGE}! Compilation failed."
fi

ok "Kernel compilation completed in ${MINUTES}m ${SECONDS}s!"
IMAGE_SIZE=$(du -h "${IMAGE}" | cut -f1)
log "Image output: ${IMAGE} (${IMAGE_SIZE})"

if [ "${NO_ZIP}" -eq 1 ]; then
    ok "Skipping flashable zip creation (--no-zip specified)."
    exit 0
fi

# ============================================================
# ANYKERNEL3 PACKAGING
# ============================================================
log "Preparing AnyKernel3 packaging..."

if [ ! -d "${AK3_DIR}/.git" ]; then
    log "Cloning AnyKernel3 (${AK3_BRANCH} branch)..."
    rm -rf "${AK3_DIR}"
    git clone --depth=1 -b "${AK3_BRANCH}" "${AK3_REPO}" "${AK3_DIR}"
fi

# Place compiled kernel image into kernels/
mkdir -p "${AK3_DIR}/kernels"
cp "${IMAGE}" "${AK3_DIR}/kernels/Image.gz-dtb"

# Create zip file in dedicated output directory
mkdir -p "${OUTPUT_DIR}"
DATE_TAG=$(date +"%Y%m%d-%H%M")
ZIP_NAME="${KERNEL_NAME}-Rosemary-${DATE_TAG}.zip"
ZIP_PATH="${OUTPUT_DIR}/${ZIP_NAME}"

cd "${AK3_DIR}"
zip -r9 "${ZIP_PATH}" . -x '*.git*' -x 'LICENSE' -x 'README.md' > /dev/null
cd "${KERNEL_DIR}"

ZIP_SIZE=$(du -h "${ZIP_PATH}" | cut -f1)

# ============================================================
# SUCCESS SUMMARY
# ============================================================
echo -e "\n${GREEN}${BOLD}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}             GhostKernel Build Successful!                  ${NC}"
echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════════════${NC}"
echo -e "  ${BOLD}Zip File${NC}    : ${CYAN}${ZIP_NAME}${NC}"
echo -e "  ${BOLD}Path${NC}        : ${OUTPUT_DIR}/${ZIP_NAME}"
echo -e "  ${BOLD}Zip Size${NC}    : ${YELLOW}${ZIP_SIZE}${NC}"
echo -e "  ${BOLD}Build Time${NC}  : ${GREEN}${MINUTES}m ${SECONDS}s${NC}"
echo -e "  ${BOLD}Root${NC}        : ${MAGENTA}BakaSU (KernelSU Manual Hook)${NC}"
echo -e "  ${BOLD}Devices${NC}     : ${CYAN}rosemary, secret, maltose${NC}"
echo -e "  ${BOLD}Android${NC}     : ${CYAN}15, 16, 17${NC}"
echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════════════${NC}\n"
