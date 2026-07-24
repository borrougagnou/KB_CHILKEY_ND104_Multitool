#!/bin/bash

set -euo pipefail

BASE_URL="https://raw.githubusercontent.com/borrougagnou/KB_CHILKEY_ND104_Multitool/refs/heads/config_file/install_folder"

DRIVER_URL="${BASE_URL}/install_keyboard_driver.sh"
CONFIG_URL="${BASE_URL}/generate_config_file.sh"


################### HELPER

check_regular_user()
{
    if [ "$(id -u)" -eq 0 ]
    then
        echo "Error: do not run this setup program as sudo/root."
        echo "Run it as your normal user."
        echo
        echo "Administrator rights will be requested only for the driver."
        return 1
    fi

    return 0
}


ask_yes_no()
{
    local question="$1"
    local answer=""

    while true; do
        read -r -p "$question [y/n]: " answer || exit 1

        case "$answer" in
            y|Y|yes|YES|Yes)
                return 0
                ;;
            n|N|no|NO|No)
                return 1
                ;;
            *)
                echo "Please answer yes or no."
                ;;
        esac
    done
}

ask_exit_or_retry()
{
    local choice=""

    while true; do
        echo
        echo "  1) Retry downloading"
        echo "  2) Exit the setup and retry later"

        read -r -p "Choice [1-2]: " choice || exit 1

        case "$choice" in
            1)
                return
                ;;
            2)
                exit 1
                ;;
            *)
                echo "Please enter 1 or 2."
                ;;
        esac
    done
}


read_required_value()
{
    local prompt="$1"
    local value=""

    while [[ -z "$value" ]]; do
        read -r -p "$prompt: " value || exit 1

        if [[ -z "$value" ]]; then
            echo "The value cannot be empty." >&2
        fi
    done

    printf '%s' "$value"
}

download_and_run()
{
    local url="${@: -1}"         # take last args
    local runner=("${@:1:$#-1}") # take everything before it is the runner

    if command -v curl >/dev/null 2>&1; then
        script_content="$(curl --fail --silent --show-error --connect-timeout 5 --max-time 10 "$url")"
        download_status=$?
    fi

    if command -v wget >/dev/null 2>&1; then
        script_content="$(wget -qO- -T 10 -t 1 "$url")"
        download_status=$?
    fi

    if [ "$download_status" -ne 0 ]; then
        return "$download_status"
    fi

    echo "#################################"
    echo "#################################"
    ${ROOT_CMD[@]} bash -c "$script_content" "SETUP"
    script_status=$?
    echo "#################################"
    echo "#################################"

    if [ "$script_status" -ne 0 ]
    then
        echo "Error: the configuration script exited with status $script_status."
        return "$script_status"
    fi

    return 0
}


################### PROGRAM


get_online_script()
{
    local script_name
    local script_url
    local local_user
    local need_perm
    local ROOT_CMD=()

    script_name="$1"
    script_url="$2"
    local_user="$3"
    need_perm="$4"

    while true; do
        echo
        echo "Requesting the $script_name file ..."
        echo "[$script_url]"

        if [[ "$need_perm" = "root" ]]; then
            if command -v sudo   >/dev/null 2>&1; then
                ROOT_CMD=(sudo)
            elif command -v doas >/dev/null 2>&1; then
                ROOT_CMD=(doas)
            elif command -v su   >/dev/null 2>&1; then
                ROOT_CMD=(su root -c)
            else
                echo "No way to obtain root privileges."
                exit 1
            fi
        else
            ROOT_CMD=()
        fi

        download_and_run "${ROOT_CMD[@]}" $script_url
        download_status=$?

        if [[ $download_status -eq 2 ]]; then
            echo "Neither curl nor wget is installed."
            echo "Install one of them and choose retry,"
            echo "or enter the location manually."

            if ask_exit_or_retry; then
                return
            fi

            continue
        fi

        if [[ $download_status -ne 0 ]]; then
            echo "Unable to contact the online location service."
            echo "The Internet connection or the service may be unavailable."

            if ask_exit_or_retry; then
                return
            fi

            continue
        else
            echo "Done"
            return
        fi
    done
    echo "end GET ONLINE SCRIPT"
}

main()
{
    operating_system="$(uname -s)"
    #operating_system="FreeBSD bil-desktop 12.0-RELEASE-p2 FreeBSD 12.0-RELEASE-p2 GENERIC  amd64"

    if ! check_regular_user; then
        return 1
    fi

    echo " =========================== "
    echo "| Linux/BSD/Mac Installer   |"
    echo "| by borrou                 |"
    echo "|                           |"
    echo "| Version 2026-09-01        |"
    echo " =========================== "
    echo

    case "$operating_system" in
        Linux)
            system_type="linux"
            echo "Linux detected."
            ;;
        FreeBSD|OpenBSD|NetBSD|DragonFly|*BSD*)
            system_type="bsd"
            echo "BSD detected: $operating_system."
            ;;
        Darwin)
            system_type="mac"
            echo "macOS detected."
            ;;
        *)
            echo "Error: unsupported operating system: ${operating_system:-unknown}."
            return 1
            ;;
    esac

    if command -v curl >/dev/null 2>&1; then
        echo "curl detected."
    elif command -v wget >/dev/null 2>&1; then
        echo "wget detected."
    else
        echo "Error: neither curl nor wget is installed."
        echo "Install curl or wget before running this setup program."
        return 1
    fi

    echo

    if [ "$system_type" = "linux" ] ||  [ "$system_type" = "bsd" ]; then
        if ask_yes_no "Do you want to install the driver? (sudo/root permission are requested)"; then
            get_online_script "driver installation script" "$DRIVER_URL" "$USER" "root"
        else
            echo "Driver installation skipped."
        fi

        echo
    fi

    if ask_yes_no "Do you want to generate the configuration file?"; then
        get_online_script "configuration script" "$CONFIG_URL" "$USER" ""
    else
        echo "Configuration generation skipped."
    fi

    echo
    echo "Setup finished."
    return 0
}

main "$@"

