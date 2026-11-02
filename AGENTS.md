# GhostKernel — Project Memory & Reference Links

## Project Overview
- **Kernel:** Linux 4.19.x CIP/ST — GhostKernel untuk Redmi Note 10S
- **Device:** Redmi Note 10S (`rosemary`, MT6785 / Helio G85)
- **RAM:** 4GB (optimasi ZRAM + multitasking penting)
- **Defconfig:** `arch/arm64/configs/rosemary_defconfig`
- **Target output:** `arch/arm64/boot/Image.gz-dtb`
- **Build script:** `b.sh` di root kernel

## Toolchain
- **Clang:** `/home/java/toolchain/clang-r416183b` (r416183b)
- **GCC aarch64:** `/home/java/toolchain/aarch64-linux-android-4.9` (stub/symlink only)
- **GCC arm32:** `/home/java/toolchain/arm-linux-androideabi-4.9` (stub/symlink only)
- **Build mode:** Pure Clang (LLVM=1, LLVM_IAS=1)

## Reference Links (User-provided)
| Nama | URL | Keterangan |
|------|-----|------------|
| BakaSU (Root) | https://github.com/Baka-SU/BakaSU | KernelSU fork untuk root — integrasi via `kernel/setup.sh` |
| Manual Hook Fix | https://github.com/xxblebleblexx/manual_hook_fix | Patch manual hook untuk kernel 4.19 CIP/ST — pakai `resuki-4.19-cip-st.patch` |
| AnyKernel3 | https://github.com/sorumstylXjava/AnyKernel/tree/rosemary | AK3 untuk rosemary — branch: `rosemary` |

## Integration Notes
### BakaSU
- Jalankan: `curl -LSs "https://raw.githubusercontent.com/Baka-SU/BakaSU/main/kernel/setup.sh" | bash -`
- Config yang dibutuhkan: `CONFIG_KSU=y`, `CONFIG_KSU_MANUAL_HOOK=y`
- Setup.sh akan: clone repo ke `./KernelSU/`, symlink `drivers/kernelsu → KernelSU/kernel`, patch Makefile & Kconfig

### Manual Hook Fix
- Patch yang dipakai: `resuki-4.19-cip-st.patch` (untuk 4.19 CIP/ST dengan `CONFIG_KSU_MANUAL_HOOK`)
- Cara apply: `git apply resuki-4.19-cip-st.patch` atau `patch -p1 < resuki-4.19-cip-st.patch`
- File kernel yang dipatch: `fs/exec.c`, `fs/open.c`, `fs/read_write.c`, `fs/stat.c`, `kernel/reboot.c`, `drivers/input/input.c`

### AnyKernel3
- Clone: `git clone -b rosemary https://github.com/sorumstylXjava/AnyKernel AnyKernel3`
- Kernel image ditempatkan di: `AnyKernel3/kernels/Image.gz-dtb`
- Zip command: `cd AnyKernel3 && zip -r9 ../GhostKernel-rosemary.zip . -x '*.git*'`
- Support device: rosemary, secret, maltose (Android 12–16+)

## Tujuan Optimasi
- **Multitasking lancar** saat pindah app (4GB RAM, terasa berat sekarang)
- **Gaming Mobile Legends** tipis-tipis, stabil
- **ZRAM** — user sudah pakai modul ZRAM, ingin lebih baik
- Seimbang antara performa dan efisiensi daya

## Notes Tersedia
- `ksun-3.0.0-susfs` — panduan SUSFS integration
- `slmk-4.19-patch` — Smart Low Memory Killer patch untuk 4.19
- `zram-multicomp-4.19` — ZRAM multi-compression untuk 4.19
- `mnskyy-dt-vt-kt` — referensi optimasi scheduler
- `neutron-clang-v23` — referensi build dengan Neutron Clang
