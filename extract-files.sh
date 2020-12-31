#!/bin/bash
#
# Copyright (C) 2016 The CyanogenMod Project
# Copyright (C) 2017-2020 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

set -e

# Load extract_utils and do some sanity checks
MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "${MY_DIR}" ]]; then MY_DIR="${PWD}"; fi

ANDROID_ROOT="${MY_DIR}/../../.."

HELPER="${ANDROID_ROOT}/tools/extract-utils/extract_utils.sh"
if [ ! -f "${HELPER}" ]; then
    echo "Unable to find helper script at ${HELPER}"
    exit 1
fi
source "${HELPER}"

# Default to sanitizing the vendor folder before extraction
CLEAN_VENDOR=true

ONLY_COMMON=
ONLY_TARGET=
SECTION=
KANG=

while [ "${#}" -gt 0 ]; do
    case "${1}" in
        --only-common )
                ONLY_COMMON=true
                ;;
        --only-target )
                ONLY_TARGET=true
                ;;
        -n | --no-cleanup )
                CLEAN_VENDOR=false
                ;;
        -k | --kang )
                KANG="--kang"
                ;;
        -s | --section )
                SECTION="${2}"; shift
                CLEAN_VENDOR=false
                ;;
        * )
                SRC="${1}"
                ;;
    esac
    shift
done

if [ -z "${SRC}" ]; then
    SRC="adb"
fi

function blob_fixup() {
    case "${1}" in
        # Load libwifi-hal-mtk.so instead of libwifi-hal.so
        vendor/bin/hw/android.hardware.wifi@1.0-service-lazy-mediatek)
            patchelf --add-needed libcompiler_rt.so ${2}
            patchelf --replace-needed libwifi-hal.so libwifi-hal-mtk.so ${2}
            ;;
        # Inject libcompiler_rt.so for fix missing symbols
        vendor/bin/hw/hostapd)
            patchelf --add-needed libcompiler_rt.so ${2}
            ;;
        vendor/bin/hw/wpa_supplicant)
            patchelf --add-needed libcompiler_rt.so ${2}
            ;;
        # Load VNDK-29 version of libmedia_helper
        vendor/lib64/hw/audio.primary.mt6785.so)
            "${PATCHELF}" --replace-needed libmedia_helper.so libmedia_helper-v29.so ${2}
            ;;
        vendor/lib/hw/audio.primary.mt6785.so)
            "${PATCHELF}" --replace-needed libmedia_helper.so libmedia_helper-v29.so ${2}
            ;;
    esac
}

# Initialize the helper for common device
if [ -z "${ONLY_TARGET}" ]; then
    # Initialize the helper for common device
    setup_vendor "${DEVICE_COMMON}" "${VENDOR}" "${ANDROID_ROOT}" true "${CLEAN_VENDOR}"

    extract "${MY_DIR}/proprietary-files.txt" "${SRC}" "${KANG}" --section "${SECTION}"
fi

# Initialize the helper for device
if [ -z "${ONLY_COMMON}" ] && [ -s "${MY_DIR}/../${DEVICE}/proprietary-files.txt" ]; then
    # Reinitialize the helper for device
    source "${MY_DIR}/../${DEVICE}/extract-files.sh"
    setup_vendor "${DEVICE}" "${VENDOR}" "${ANDROID_ROOT}" false "${CLEAN_VENDOR}"

    extract "${MY_DIR}/../${DEVICE}/proprietary-files.txt" "${SRC}" "${KANG}" --section "${SECTION}"
fi

"${MY_DIR}/setup-makefiles.sh"
