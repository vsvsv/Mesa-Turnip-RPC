#!/bin/bash -e

# Define colors for terminal output
green='\033[0;32m'
red='\033[0;31m'
blue='\033[0;34m'
nocolor='\033[0m'
tbold=$(tput bold)
tnormal=$(tput sgr0)

for ARGUMENT in "$@"
do
   KEY=$(echo $ARGUMENT | cut -f1 -d=)

   KEY_LENGTH=${#KEY}
   VALUE="${ARGUMENT:$KEY_LENGTH+1}"

   export "$KEY"="$VALUE"
done

if [[ "$1" != "build"  ]]; then
    echo -e "${green}${tbold}Mesa Turnip Driver Builder ${tnormal}${green}$nocolor"
    echo "Original code by Shankar Vallabhan A (https://github.com/v3kt0r-87/Mesa-Turnip-Builder)"
    echo
    echo "Usage:"
    echo -e "${blue}$0 build ${nocolor}"
    echo "      Build Turnip drivers by downloading Android NDK and Mesa from the internet."
    echo
    echo -e "${blue}$0 build NDK_BIN_DIR=${green}\"/${nocolor}FULL_PATH_TO_YOUR_NDK${green}/toolchains/llvm/prebuilt/${nocolor}YOUR_PLATFORM${green}/bin\"${nocolor}"
    echo "      Build using already installed Android NDK instead of downloading."
    echo
    exit
fi

# Define colors for terminal output
green='\033[0;32m'
red='\033[0;31m'
nocolor='\033[0m'

mtdb_echo() {
  echo -e "${nocolor}${tbold}[${blue}Turnip Builder${nocolor}${tbold}]${nocolor} $@"
}

mtdb_fatal() {
    mtdb_echo "${nocolor}${tbold}[${red}FATAL${nocolor}${tbold}]${nocolor} ${red}$@"
    exit -1
}

# Define Mesa version and download URL
mesadir="mesa-mesa-25.1.4"
mesaver="https://gitlab.freedesktop.org/mesa/mesa/-/archive/mesa-25.1.4/${mesadir}.zip"
ndk_sdkver="34" # Needed for mesa-mesa-25.1.4

# Define working directories
workdir="$(pwd)/turnip_workdir"         # Base directory for all operations
magiskdir="$workdir/turnip_module"      # Directory to create the Magisk module

DRIVER_FILE="vulkan.turnip.so"          # Output Vulkan Driver (emulator)
META_FILE="meta.json"                   # Metadata

ZIP_FILE_MAGISK="Turnip-25.1.4-MAGISK-KSU.zip"
ZIP_FILE_EMULATOR="Turnip-25.1.4-EMULATOR.zip"

# List of required packages to build the Turnip driver
deps="meson ninja patchelf unzip curl flex bison zip glslang"

mtdb_echo "Checking system for required dependencies..."

deps_fail_explanation="${red}- Please ensure you have \"$nocolor$deps$red\" and \"${nocolor}pip$red\" (or \"${nocolor}pip3$red\") utilities installed on your system. $nocolor"

# Check for required dependencies 
for deps_chk in $deps; do
    sleep 0.2
    if command -v "$deps_chk" >/dev/null 2>&1; then
        mtdb_echo "${green}- $deps_chk found $nocolor"
    else
        mtdb_echo "${red}- $deps_chk not found, cannot continue. $nocolor"
        mtdb_echo "$deps_fail_explanation"
        exit -1
    fi
done


# Check if we have pip installed
pip_exec="pip"
sleep 0.5
if command -v "$pip_exec" >/dev/null 2>&1; then
    mtdb_echo "${green}- $pip_exec found $nocolor"
else
    pip_exec="pip3"
    if command -v "$pip_exec" >/dev/null 2>&1; then
        mtdb_echo "${green}- $pip_exec found $nocolor"
    else
            mtdb_echo "$red - Neither \"${nocolor}pip$red\" nor \"${nocolor}pip3$red\" executale are found, cannot continue. $nocolor"
            mtdb_echo "$deps_fail_explanation"
        exit -1
    fi
fi

mtdb_echo "Installing Python dependencies for Mesa..."
eval "$pip_exec install mako packaging pyyaml" || mtdb_fatal "Failed to install required Python packages. If your system does not support installing global packages, can enter Poetry virtual environment via ${tbold}eval \"\$(poetry env activate)\"${tnormal}$red before executing this script to install Python packages locally."
sleep 0.2

# TODO: Uncomment
cd $workdir
# # Clean work directory if it exists
# if [ -d "$workdir" ]; then
#     mtdb_echo "Work directory already exists. Cleaning before proceeding..."
#     rm -rf "$workdir"
#     sleep 0.2
# fi
#
# mtdb_echo "Creating and entering the work directory..."
# mkdir -p "$workdir" && cd "$_"

# Define Android NDK binary path and version
ndk_bin=""
if [[ -n "$NDK_BIN_DIR" ]]; then
    mtdb_echo "Skipping downloading Android NDK..."
    ndk_bin="$NDK_BIN_DIR"

    mtdb_echo "Checking correctness of supplied NDK_BIN_DIR..."
    test_cmd="aarch64-linux-android${ndk_sdkver}-clang"
    if command -v "$ndk_bin/$test_cmd" >/dev/null 2>&1; then
        mtdb_echo "${green}- found SDK $ndk_sdkver executables in NDK_BIN_DIR$nocolor"
    else
        mtdb_echo "${red}- $test_cmd is not found in NDK_BIN_DIR=\"$NDK_BIN_DIR\"$nocolor"
        mtdb_echo "${red}  Check that NDK_BIN_DIR is pointing to Android NDK bin diretory"
        mtdb_echo "${red}  (e. g. \"/FULL_PATH_TO_YOUR_NDK/toolchains/llvm/prebuilt/YOUR_PLATFORM/bin\"),"
        mtdb_echo "${red}  and bin directory has utilities for SDK version ${tbold}$ndk_sdkver${tnormal}${red} (needed for $mesadir)"
        echo
        exit -1
    fi
else
    ndkdir="android-ndk-r29-beta2"
    ndkver="https://dl.google.com/android/repository/${ndkdir}-linux.zip"

    # Download Android NDK
    mtdb_echo "Downloading Android NDK..." $'\n'
    curl $ndkver --output "$ndkdir".zip

    mtdb_echo "Extracting Android NDK..." $'\n'
    unzip "$ndkdir".zip &> /dev/null

    ndk_bin="$workdir/$ndkdir/toolchains/llvm/prebuilt/linux-x86_64/bin"
fi
mtdb_echo "Using Android NDK binaries from \"$ndk_bin\""

# TODO: Uncomment
cd $mesadir
# # Download Mesa source
# mtdb_echo "Downloading Latest Mesa source..."
# curl $mesaver --output "$mesadir".zip
#
# mtdb_echo "Extracting Mesa source..."
# unzip "$mesadir".zip &> /dev/null
# cd $mesadir

# Set toolchain variables
export CC=clang
export CXX=clang++
export AR=llvm-ar
export RANLIB=llvm-ranlib
export STRIP=llvm-strip
export OBJDUMP=llvm-objdump
export OBJCOPY=llvm-objcopy
export LDFLAGS="-fuse-ld=lld"

# Create a temporary directory for fake cc/c++
mkdir -p /tmp/fake-cc

# Create symbolic links to NDK-Clang
ln -sf "$ndk_bin/clang" /tmp/fake-cc/cc
ln -sf "$ndk_bin/clang++" /tmp/fake-cc/c++

# Prepend both fake-cc and NDK bin to PATH
export PATH="/tmp/fake-cc:$ndk_bin:$PATH"

mtdb_echo "Creating Meson cross file..."

cat <<EOF >"android-aarch64.txt"
[binaries]
ar = '$ndk_bin/llvm-ar'
c = ['ccache', '$ndk_bin/aarch64-linux-android${ndk_sdkver}-clang', '-O2']
cpp = ['ccache', '$ndk_bin/aarch64-linux-android${ndk_sdkver}-clang++', '-O2', '--start-no-unused-arguments', '-fno-exceptions', '-fno-unwind-tables', '-fno-asynchronous-unwind-tables', '-static-libstdc++', '--end-no-unused-arguments', '-Wno-error=c++11-narrowing']
c_ld = '$ndk_bin/ld.lld'
cpp_ld = '$ndk_bin/ld.lld'
strip = '$ndk_bin/aarch64-linux-android-strip'
pkg-config = ['env', 'PKG_CONFIG_LIBDIR=NDKDIR/pkg-config', '/usr/bin/pkg-config']

[host_machine]
system = 'android'
cpu_family = 'aarch64'
cpu = 'armv8'
endian = 'little'
EOF

cat <<EOF >"native.txt"
[build_machine]
c = ['ccache', 'clang']
cpp = ['ccache', 'clang++']
ar = 'llvm-ar'
strip = 'llvm-strip'
c_ld = 'ld.lld'
cpp_ld = 'ld.lld'
system = 'linux'
cpu_family = 'x86_64'
cpu = 'x86_64'
endian = 'little'
EOF

mtdb_echo "Generating build files..."
CC=clang CXX=clang++ meson setup build-android-aarch64 \
    --cross-file "$workdir/$mesadir/android-aarch64.txt" \
    --native-file "$workdir/$mesadir/native.txt" \
    -Dbuildtype=release \
    -Dplatforms=android \
    -Dplatform-sdk-version="${ndk_sdkver}" \
    -Dandroid-stub=true \
    -Dgallium-drivers= \
    -Dvulkan-drivers=freedreno \
    -Dfreedreno-kmds=kgsl \
    -Db_lto=true \
    -Degl=disabled \
    -Dstrip=true || mtdb_fatal "Failed to generate Meson build files. Check the error above."

# Compile build files using Ninja
mtdb_echo "Compiling build files..."
ninja -C build-android-aarch64 || mtdb_fatal "Failed to compile Mesa. Check the error above."

mtdb_echo "Using patchelf to match .so name..."
cp "$workdir"/"$mesadir"/build-android-aarch64/src/freedreno/vulkan/libvulkan_freedreno.so "$workdir"
cd "$workdir"



if ! [ -a libvulkan_freedreno.so ]; then
    echo -e "$red Build failed! libvulkan_freedreno.so not found $nocolor" && exit 1
fi

echo "Prepare magisk module structure..." $'\n'
p1="system/vendor/lib64/hw"
mkdir -p "$magiskdir/$p1"
cd "$magiskdir"

echo "Copy necessary files from the work directory..." $'\n'
cp "$workdir"/libvulkan_freedreno.so "$workdir"/vulkan.adreno.so
cp "$workdir"/vulkan.adreno.so "$magiskdir/$p1"

meta="META-INF/com/google/android"
mkdir -p "$meta"

# Create update-binary
cat <<EOF >"$meta/update-binary"
#!/sbin/sh

#################
# Initialization
#################

umask 022

# echo before loading util_functions
ui_print() { echo "\$1"; }

require_new_magisk() {
  ui_print "*******************************"
  ui_print " Please install Magisk v25.2+! "
  ui_print "*******************************"
  exit 1
}

#########################
# Load util_functions.sh
#########################

OUTFD=\$2
ZIPFILE=\$3

mount /data 2>/dev/null

[ -f /data/adb/magisk/util_functions.sh ] || require_new_magisk
. /data/adb/magisk/util_functions.sh
[ \$MAGISK_VER_CODE -lt 25200 ] && require_new_magisk

install_module
exit 0
EOF

# Create updater-script
cat <<EOF >"$meta/updater-script"
#MAGISK
EOF

cat <<EOF >"uninstall.sh"
find /data/user_de/*/*/*cache/* -iname "*shader*" -exec rm -rf {} +
find /data/data/* -iname "*shader*" -exec rm -rf {} +
find /data/data/* -iname "*graphitecache*" -exec rm -rf {} +
find /data/data/* -iname "*gpucache*" -exec rm -rf {} +
find /data_mirror/data*/*/*/*/* -iname "*shader*" -exec rm -rf {} +
find /data_mirror/data*/*/*/*/* -iname "*graphitecache*" -exec rm -rf {} +
find /data_mirror/data*/*/*/*/* -iname "*gpucache*" -exec rm -rf {} +
EOF

cat <<EOF >"module.prop"
id=turnip-mesa
name=Freedreno Turnip Vulkan Driver STABLE
version=v25.1.4
versionCode=20250619
author=V3KT0R-87
description=Turnip is an open-source vulkan driver for devices with Adreno 6xx-7xx GPUs.
updateJson=https://raw.githubusercontent.com/v3kt0r-87/Mesa-Turnip-Builder/refs/heads/stable/update.json
EOF

cat <<EOF >"customize.sh"
MODVER=\`grep_prop version \$MODPATH/module.prop\`
MODVERCODE=\`grep_prop versionCode \$MODPATH/module.prop\`

ui_print ""
ui_print "Version=\$MODVER "
ui_print "MagiskVersion=\$MAGISK_VER"
ui_print ""
ui_print "Freedreno Turnip Vulkan Driver -V3KT0R"
ui_print "Adreno Driver Support Group - Telegram"
ui_print ""
sleep 1.25

ui_print ""
ui_print "Checking Device info ..."
sleep 1.25

[ \$(getprop ro.system.build.version.sdk) -lt 34 ] && echo "Android 14 is now required! Aborting ..." && abort
echo ""
echo "Everything looks fine .... proceeding"
ui_print ""
ui_print "Installing Driver Please Wait ..."
ui_print ""

sleep 1.25
set_perm_recursive \$MODPATH/system 0 0 755 u:object_r:system_file:s0
set_perm_recursive \$MODPATH/system/vendor 0 2000 755 u:object_r:vendor_file:s0
set_perm \$MODPATH/system/vendor/lib64/hw/vulkan.adreno.so 0 0 0644 u:object_r:same_process_hal_file:s0

ui_print ""
ui_print " Cleaning GPU Cache ... Please wait!"
find /data/user_de/*/*/*cache/* -iname "*shader*" -exec rm -rf {} +
find /data/data/* -iname "*shader*" -exec rm -rf {} +
find /data/data/* -iname "*graphitecache*" -exec rm -rf {} +
find /data/data/* -iname "*gpucache*" -exec rm -rf {} +
find /data_mirror/data*/*/*/*/* -iname "*shader*" -exec rm -rf {} +
find /data_mirror/data*/*/*/*/* -iname "*graphitecache*" -exec rm -rf {} +
find /data_mirror/data*/*/*/*/* -iname "*gpucache*" -exec rm -rf {} +

ui_print ""
ui_print "- Gpu Cache Cleared ..."
ui_print ""

ui_print "Driver installed Successfully"
sleep 1.25

ui_print ""
ui_print "All done, Please REBOOT device"
ui_print ""
ui_print "BY: @VEKT0R_87"
ui_print ""
EOF

echo "Packing driver files into Magisk/KSU module ..." $'\n'

zip -r "$workdir/$ZIP_FILE_MAGISK" * &> /dev/null

if [[ ! -f "$workdir/$ZIP_FILE_MAGISK" ]]; then
    echo -e "${red}Error: Zipping driver files failed.${nocolor}"
    exit 1
else
    clear

    echo " Its time to create Turnip build for EMULATOR"

    sleep 2

    cd ..

    mv vulkan.adreno.so vulkan.turnip.so

# Create meta.json file for turnip emulator
 cat <<EOF > "$META_FILE"
{
  "schemaVersion": 1,
  "name": "Freedreno Turnip Driver STABLE",
  "description": "Compiled using Android NDK 28b",
  "author": "v3kt0r-87",
  "packageVersion": "3",
  "vendor": "Mesa3D",
  "driverVersion": "Vulkan 1.4.311",
  "minApi": 34,
  "libraryName": "vulkan.turnip.so"
}
EOF

# Zip the turnip .so file and meta.json file
    if ! zip "$workdir/$ZIP_FILE_EMULATOR" "$DRIVER_FILE" "$META_FILE" &> /dev/null; then
        echo -e "${red}Error: Zipping driver files failed.${nocolor}"
        exit 1
    fi

    clear

    echo -e "$green-All done, you can take your drivers from here;$nocolor" $'\n'
    echo "$workdir/$ZIP_FILE_MAGISK"
    echo "$workdir/$ZIP_FILE_EMULATOR"
    echo -e "$green Build Finished :). $nocolor" $'\n'

    # Cleanup 
    rm "$DRIVER_FILE" "$META_FILE"

    # Clean up fake-cc directory and symbolic links on exit
    rm -rf /tmp/fake-cc/cc
    rm -rf /tmp/fake-cc/c++
    rm -rf /tmp/fake-cc
    
fi
