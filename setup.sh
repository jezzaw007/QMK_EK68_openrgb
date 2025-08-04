#!/bin/bash
set -e # Exit immediately if any command fails

echo "--- Starting QMK Epomaker EK68 Setup ---"

# 1. Install System Pre-requisites
echo ""
echo "--- Step 1: Installing system packages (sudo password may be required) ---"
if command -v apt &> /dev/null; then
    echo "Detected Debian/Ubuntu-based system. Using apt..."
    sudo apt update -y
    sudo apt install -y build-essential gcc-avr avr-libc binutils-avr arm-none-eabi-gcc arm-none-eabi-binutils arm-none-eabi-newlib git
elif command -v dnf &> /dev/null; then
    echo "Detected Fedora/RHEL-based system. Using dnf..."
    sudo dnf check-update -y
    sudo dnf install -y @development-tools \
                         avr-gcc avr-libc avr-binutils \
                         arm-none-eabi-gcc arm-none-eabi-binutils arm-none-eabi-newlib \
                         git
elif command -v pacman &> /dev/null; then
    echo "Detected Arch Linux-based system. Using pacman..."
    sudo pacman -Sy --noconfirm # Sync and refresh package list, --noconfirm to auto-yes
    sudo pacman -S --noconfirm base-devel avr-gcc avr-binutils avr-libc arm-none-eabi-gcc arm-none-eabi-binutils arm-none-eabi-newlib git
else
    echo "Error: No supported package manager (apt, dnf, pacman) found. Please install dependencies manually."
    exit 1
fi

# 2. Install Python packages & Run QMK Setup
echo ""
echo "--- Step 2: Installing QMK CLI Python package ---"
pip install -r requirements.txt

echo "--- Step 2: Running QMK setup (this may take a while as it clones the QMK firmware repo) ---"
qmk setup

# Define the root of the QMK firmware directory
QMK_FIRMWARE_ROOT="${HOME}/qmk_firmware"

# 3. Create Custom Keymap Folder and Configure Files
echo ""
echo "--- Step 3: Configuring custom keymap for EK68 ---"

# Navigate to the keyboard directory
QMK_KEYBOARD_DIR="${QMK_FIRMWARE_ROOT}/keyboards/epomaker/ek68"
echo "Navigating to: ${QMK_KEYMAP_DIR}"
cd "${QMK_KEYBOARD_DIR}"

# Define the custom keymap path
MY_RGB_KEYMAP_PATH="keymaps/my_rgb"
MY_RGB_RULES_MK="${MY_RGB_KEYMAP_PATH}/rules.mk"
MY_RGB_CONFIG_H="${MY_RGB_KEYMAP_PATH}/config.h"

# Create keymap folder if it doesn't exist
if [ ! -d "${MY_RGB_KEYMAP_PATH}" ]; then
    echo "Creating keymap folder: ${MY_RGB_KEYMAP_PATH}"
    cp -r keymaps/via "${MY_RGB_KEYMAP_PATH}"
else
    echo "Keymap folder '${MY_RGB_KEYMAP_PATH}' already exists, skipping copy."
fi

# Edit rules.mk to enable RGB Matrix
echo "Enabling RGB_MATRIX_ENABLE in ${MY_RGB_RULES_MK}..."
if [[ "$(uname)" == "Darwin" ]]; then # macOS specific sed syntax
    sed -i '' 's/^[[:space:]]*#\?RGB_MATRIX_ENABLE[[:space:]]*=.*$/RGB_MATRIX_ENABLE = yes/' "${MY_RGB_RULES_MK}"
else # Linux/WSL sed syntax
    sed -i 's/^[[:space:]]*#\?RGB_MATRIX_ENABLE[[:space:]]*=.*$/RGB_MATRIX_ENABLE = yes/' "${MY_RGB_RULES_MK}"
fi
echo "RGB_MATRIX_ENABLE set to 'yes'."

# Configure config.h
echo "Overwriting ${MY_RGB_CONFIG_H} with specified configuration..."
cat << 'EOF' > "${MY_RGB_CONFIG_H}"
#pragma once

#include "config_common.h"

#define VENDOR_ID       0x1234
#define PRODUCT_ID      0x5678
#define DEVICE_VER      0x0001
#define MANUFACTURER    Epomaker
#define PRODUCT         EK68 RGB

/* USB Device descriptor parameter */
#define MATRIX_ROWS 5
#define MATRIX_COLS 14

/* Select hand configuration (if split) */
// #define MASTER_RIGHT

/* RGB Matrix Configuration */
#define RGB_MATRIX_KEYPRESSES   // Enable effects on keypress
#define RGB_MATRIX_FRAMEBUFFER_EFFECTS
#define RGB_MATRIX_STARTUP_MODE RGB_MATRIX_CYCLE_LEFT_RIGHT
EOF
echo "config.h updated successfully."

# 4. Optional: Customize keymap.c (Manual Step)
echo ""
echo "--- Step 4: Optional Keymap Customization ---"
echo "If you want layer-based lighting or custom animations, you can now edit:"
echo "  ${QMK_KEYBOARD_DIR}/${MY_RGB_KEYMAP_PATH}/keymap.c"
echo "This is a manual step and cannot be automated by this script."

# 5. Build the Firmware
echo ""
echo "--- Step 5: Building the Firmware ---"
echo "Navigating back to QMK firmware root: ${QMK_FIRMWARE_ROOT}"
cd "${QMK_FIRMWARE_ROOT}"
echo "Compiling firmware for epomaker/ek68 with 'my_rgb' keymap..."
qmk compile -kb epomaker/ek68 -km my_rgb
echo "Firmware built! The .hex (or .bin) file is located in: ${QMK_FIRMWARE_ROOT}/.build/"

echo ""
echo "--- Setup & Build Complete! ---"
echo "Next Steps (Manual Flashing):"
echo "1. Put your Epomaker EK68 into bootloader mode (usually via the hardware reset button on the PCB)."
echo "2. Once in bootloader mode, run the following command to flash the firmware:"
echo "   qmk flash -kb epomaker/ek68 -km my_rgb"
echo ""
echo "After flashing, your EK68 should appear in OpenRGB as an RGB Matrix device."
