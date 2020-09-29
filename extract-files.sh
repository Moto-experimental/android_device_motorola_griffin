#!/bin/bash
#
# Copyright (C) 2016 The CyanogenMod Project
# Copyright (C) 2017-2023 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

set -e

DEVICE=griffin
VENDOR=motorola

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

KANG=
SECTION=

while [ "${#}" -gt 0 ]; do
    case "${1}" in
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
        # Fix xml version
        product/etc/permissions/vendor.qti.hardware.data.connection-V1.0-java.xml | product/etc/permissions/vendor.qti.hardware.data.connection-V1.1-java.xml)
            sed -i 's|xml version="2.0"|xml version="1.0"|g' "${2}"
            ;;

        # Load wrapped shim
        vendor/lib64/libmdmcutback.so)
            for LIBQSAP_SHIM in $(grep -L "libqsap_shim.so" "${2}"); do
                "${PATCHELF}" --add-needed "libqsap_shim.so" "$LIBQSAP_SHIM"
            done
            ;;

        # Fix missing symbols
        vendor/lib64/libril-qc-qmi-1.so)
            for LIBCUTILS_SHIM in $(grep -L "libcutils_shim.so" "${2}"); do
                "${PATCHELF}" --add-needed "libcutils_shim.so" "$LIBCUTILS_SHIM"
            done
            ;;

        # Fix encryption blob names
        vendor/lib64/hw/gatekeeper.msm8996.so)
            "${PATCHELF}" --set-soname gatekeeper.msm8996.so "${2}"
            ;;

        vendor/lib64/hw/keystore.msm8996.so)
            "${PATCHELF}" --set-soname keystore.msm8996.so "${2}"
            ;;

        # Fix thermal engine config path
        vendor/bin/thermal-engine)
            sed -i "s|/system/etc/thermal|/vendor/etc/thermal|g" "${2}"
            ;;

        # Shim libgui for mot_gpu_mapper
        vendor/lib/libmot_gpu_mapper.so)
            sed -i "s/libgui/libwui/" "${2}"
            ;;

        vendor/lib/libjustshoot.so)
            for LIBJUSTSHOOT_SHIM in $(grep -L "libjustshoot_shim.so" "${2}"); do
                "${PATCHELF}" --add-needed libjustshoot_shim.so "$LIBJUSTSHOOT_SHIM"
            done
            ;;

        vendor/lib/libmmcamera2_sensor_modules.so)
            sed -i "s|/system/etc/camera/|/vendor/etc/camera/|g" "${2}"
            ;;

        vendor/lib/libmmcamera_vstab_module.so | vendor/lib/libmot_ois_data.so)
            "${PATCHELF}" --remove-needed libandroid.so "${2}"
            ;;

        vendor/lib/lib_mottof.so | vendor/lib/libmmcamera_vstab_module.so | vendor/lib/libjscore.so)
            sed -i "s/libgui/libwui/" "${2}"
            ;;

        vendor/lib/libcamerabgprocservice.so)
            "${PATCHELF}" --remove-needed libcamera_client.so "${2}"
            ;;

        vendor/lib/libcamerabgproc-jni.so)
            "${PATCHELF}" --remove-needed libandroid_runtime.so "${2}"
            "${PATCHELF}" --remove-needed libandroidfw.so "${2}"
            "${PATCHELF}" --remove-needed libmedia.so "${2}"
            "${PATCHELF}" --remove-needed libnativehelper.so "${2}"
            for LIBJNI_SHIM in $(grep -L "libjni_shim.so" "${2}"); do
                "${PATCHELF}" --add-needed libjni_shim.so "$LIBJNI_SHIM"
            done
            ;;

        vendor/lib/libjustshoot.so | vendor/lib/libjscore.so)
            "${PATCHELF}" --remove-needed libstagefright.so "${2}"
            ;;

        vendor/lib64/hw/gatekeeper.msm8996.so | vendor/lib64/hw/keystore.msm8996.so | vendor/lib64/lib_fpc_tac_shared.so | vendor/lib64/libSecureUILib.so)
            sed -i "s|/firmware/image|/vendor/f/image|g" "${2}"
            ;;

        vendor/lib/hw/camera.msm8996.so)
            sed -i "s|service.bootanim.exit|service.bootanim.hold|g" "${2}"
            ;;

        # memset shim
        vendor/bin/charge_only_mode)
            for LIBMEMSET_SHIM in $(grep -L "libmemset_shim.so" "${2}"); do
                "${PATCHELF}" --add-needed "libmemset_shim.so" "$LIBMEMSET_SHIM"
            done
            ;;
    esac
}

# Initialize the helper
setup_vendor "${DEVICE}" "${VENDOR}" "${ANDROID_ROOT}" false "${CLEAN_VENDOR}"

extract "${MY_DIR}/proprietary-files.txt" "${SRC}" "${KANG}" --section "${SECTION}"

"${MY_DIR}/setup-makefiles.sh"
