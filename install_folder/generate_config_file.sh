#!/bin/bash

APP_NAME="Chilkey_ND104"
case "$(uname)" in
    Darwin)
        CONFIG_DIR="$HOME/Library/Application Support/$APP_NAME"
        ;;
    Linux|FreeBSD|OpenBSD|NetBSD|DragonFly)
        CONFIG_DIR="$HOME/.config/$APP_NAME"
        ;;
    *)
        echo "Unsupported operating system."
        exit 1
        ;;
esac
CONFIG_FILE="$CONFIG_DIR/config.json"
LOCATION_URL="http://ip-api.com/json/?fields=status,message,country,city,lat,lon"

country=""
city=""
latitude=""
longitude=""
geolocation="false"
json_tool=""
location_response=""
KB_VID="6d67"
KB_PID="016c"
SCREEN_VID="5542"
SCREEN_PID="0001"


export LC_NUMERIC=C


################### HELPER


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


select_json_tool()
{
    if command -v jq >/dev/null 2>&1; then
        json_tool="jq"
        return 0
    fi

    if command -v python3 >/dev/null 2>&1; then
        json_tool="python3"
        return 0
    fi

    return 1
}


download_location()
{
    if command -v curl >/dev/null 2>&1; then
        curl --fail --silent --show-error --connect-timeout 5 --max-time 10 "$1"
        return $?
    fi

    if command -v wget >/dev/null 2>&1; then
        wget -qO- -T 10 -t 1 "$1"
        return $?
    fi

    return 2
}


################### LOCATION MANUAL


is_valid_coordinate()
{
    local value="$1"
    local minimum="$2"
    local maximum="$3"

    if [[ ! "$value" =~ ^-?[0-9]+([.][0-9]+)?$ ]]; then
        return 1
    fi

    awk -v value="$value" -v minimum="$minimum" -v maximum="$maximum" 'BEGIN { exit !(value >= minimum && value <= maximum) }'
}


read_coordinate()
{
    local prompt="$1"
    local minimum="$2"
    local maximum="$3"
    local value=""

    while true; do
        read -r -p "$prompt: " value || exit 1

        if is_valid_coordinate "$value" "$minimum" "$maximum"; then
            printf '%s' "$value"
            return
        fi

        echo "Enter a number between $minimum and $maximum." >&2
        echo "Use a dot as decimal separator, for example: 48.8566" >&2
    done
}


ask_manual_location()
{
    echo
    echo "Enter the location manually."

    country=$(  read_required_value "Country")
    city=$(     read_required_value "City")
    latitude=$( read_coordinate     "Latitude"  "-90"  "90")
    longitude=$(read_coordinate     "Longitude" "-180" "180")
}


edit_location_field()
{
    local choice=""

    echo
    echo "Which value do you want to modify?"
    echo "  1) Country"
    echo "  2) City"
    echo "  3) Latitude"
    echo "  4) Longitude"

    while true; do
        read -r -p "Choice [1-4]: " choice || exit 1

        case "$choice" in
            1)
                country=$(read_required_value "Country")
                return
                ;;
            2)
                city=$(read_required_value "City")
                return
                ;;
            3)
                latitude=$(read_coordinate "Latitude" "-90" "90")
                return
                ;;
            4)
                longitude=$(read_coordinate "Longitude" "-180" "180")
                return
                ;;
            *)
                echo "Please enter a number from 1 to 4."
                ;;
        esac
    done
}


show_location()
{
    echo
    echo "Location information:"
    echo "  Country:   $country"
    echo "  City:      $city"
    echo "  Latitude:  $latitude"
    echo "  Longitude: $longitude"
}


confirm_location()
{
    while true; do
        show_location

        if ask_yes_no "Is this information correct?"; then
            return
        fi

        edit_location_field
    done
}


ask_manual_or_retry()
{
    local choice=""

    while true; do
        echo
        echo "  1) Enter the location manually"
        echo "  2) Retry the online service"

        read -r -p "Choice [1-2]: " choice || exit 1

        case "$choice" in
            1)
                ask_manual_location
                return 0
                ;;
            2)
                return 1
                ;;
            *)
                echo "Please enter 1 or 2."
                ;;
        esac
    done
}


################### LOCATION AUTO


get_online_location()
{
    local download_status=0
    local api_status=""
    local api_message=""

    while true; do
        echo
        echo "Requesting the location from ip-api.com..."

        location_response=$(download_location $LOCATION_URL)
        download_status=$?

        if [[ $download_status -eq 2 ]]; then
            echo "Neither curl nor wget is installed."
            echo "Install one of them and choose retry,"
            echo "or enter the location manually."

            if ask_manual_or_retry; then
                return
            fi

            continue
        fi

        if [[ $download_status -ne 0 ]]; then
            echo "Unable to contact the online location service."
            echo "The Internet connection or the service may be unavailable."

            if ask_manual_or_retry; then
                return
            fi

            continue
        fi

        api_status=$(printf '%s' "$location_response" | read_json_field "status")
        if [[ $? -ne 0 ]]; then
            echo "The online service returned invalid JSON data."

            if ask_manual_or_retry; then
                return
            fi

            continue
        fi

        if [[ "$api_status" != "success" ]]; then
            api_message=$(printf '%s' "$location_response" | read_json_field "message" 2>/dev/null)

            echo "The online service could not determine the location."

            if [[ -n "$api_message" ]]; then
                echo "Reason: $api_message"
            fi

            if ask_manual_or_retry; then
                return
            fi

            continue
        fi

        country=$(  printf '%s' "$location_response" | read_json_field "country")
        city=$(     printf '%s' "$location_response" | read_json_field "city")
        latitude=$( printf '%s' "$location_response" | read_json_field "lat")
        longitude=$(printf '%s' "$location_response" | read_json_field "lon")

        if [[ -z "$country" || -z "$city" ]] ||
           ! is_valid_coordinate "$latitude" "-90" "90" ||
           ! is_valid_coordinate "$longitude" "-180" "180"; then

            echo "The online service returned incomplete location information."

            if ask_manual_or_retry; then
                return
            fi

            continue
        fi

        confirm_location
        return
    done
}


################### JSON CONFIG


read_json_field()
{
    local field="$1"

    if [[ "$json_tool" == "jq" ]]; then
        jq -er --arg field "$field" '.[$field] | select(. != null) | tostring'
        return
    fi

    python3 -c '
import json
import sys

try:
    value = json.load(sys.stdin).get(sys.argv[1])
except (json.JSONDecodeError, OSError):
    sys.exit(1)

if value is None:
    sys.exit(1)

if isinstance(value, bool):
    print("true" if value else "false")
else:
    print(value)
' "$field"
}


write_config()
{
    local temporary_file=""

    mkdir -p "$CONFIG_DIR" || return 1

    temporary_file=$(mktemp "$CONFIG_DIR/config.json.tmp.XXXXXX") || return 1

    if [[ "$json_tool" == "jq" ]]; then
        if ! jq -n \
            --arg city    "$city"    \
            --arg country "$country" \
            --arg KB_VID     "$KB_VID"     \
            --arg KB_PID     "$KB_PID"     \
            --arg SCREEN_VID "$SCREEN_VID" \
            --arg SCREEN_PID "$SCREEN_PID" \
            --argjson latitude    "$latitude"    \
            --argjson longitude   "$longitude"   \
            --argjson geolocation "$geolocation" \
            '{
              "Information": {
                "city":    $city,
                "country": $country,
                "lat":     $latitude,
                "lon":     $longitude
              },
              "Keyboard": {
                "Keyboard_VID": $KB_VID,
                "Keyboard_PID": $KB_PID,
                "Screen_VID":   $SCREEN_VID,
                "Screen_PID":   $SCREEN_PID
              },
              "Weather": {
                "geolocation":  $geolocation,
                "periodic_run": "1h"
              }
            }' > "$temporary_file"; then

            rm -f "$temporary_file"
            return 1
        fi
    else
        if ! COUNTRY="$country" \
             CITY="$city"       \
             KB_VID="$KB_VID"         \
             KB_PID="$KB_PID"         \
             SCREEN_VID="$SCREEN_VID" \
             SCREEN_PID="$SCREEN_PID" \ 
             LATITUDE="$latitude"   \
             LONGITUDE="$longitude" \
             GEOLOCATION="$geolocation" \
             python3 - "$temporary_file" <<'PYTHON_SCRIPT'
import json
import os
import sys

config = {
    "Information": {
        "city":    os.environ["CITY"],
        "country": os.environ["COUNTRY"],
        "lat":     float(os.environ["LATITUDE"]),
        "lon":     float(os.environ["LONGITUDE"]),
    },
    "Keyboard": {
        "Keyboard_VID": os.environ["KB_VID"],
        "Keyboard_PID": os.environ["KB_PID"],
        "Screen_VID":   os.environ["SCREEN_VID"],
        "Screen_PID":   os.environ["SCREEN_PID"]
    },
    "Weather": {
        "geolocation":  os.environ["GEOLOCATION"] == "true",
        "periodic_run": "30m",
    },
}

with open(sys.argv[1], "w", encoding="utf-8") as config_file:
    json.dump(
        config,
        config_file,
        ensure_ascii=False,
        indent=2,
    )

    config_file.write("\n")
PYTHON_SCRIPT
        then
            rm -f "$temporary_file"
            return 1
        fi
    fi

    if ! mv "$temporary_file" "$CONFIG_FILE"; then
        rm -f "$temporary_file"
        return 1
    fi

    return 0
}


################### MAIN


main()
{
    if ! select_json_tool; then
        echo "Error: jq or python3 is required."
        echo "One of them is needed to read and create valid JSON."
        echo
        echo "Installation examples:"
        echo "  Debian/Ubuntu: sudo apt install jq curl"
        echo "  Fedora:        sudo dnf install jq curl"
        echo "  Arch Linux:    sudo pacman -S jq curl"
        exit 1
    fi


    echo " =========================== "
    echo "| Config file generator     |"
    echo "| by borrou                 |"
    echo "|                           |"
    echo "| Version 2026-07-25        |"
    echo " =========================== "
    echo

    if ask_yes_no "Use the online service to detect your actual location?"; then
        get_online_location
    else
        ask_manual_location
        confirm_location
    fi

    echo

    if ask_yes_no "Enable weather geolocation?"; then
        geolocation="true"
    else
        geolocation="false"
    fi

    if ! write_config; then
        echo "Error: unable to create the config file:" >&2
        echo "$CONFIG_FILE" >&2
        exit 1
    fi

    echo
    echo "Config file created or updated:"
    echo "$CONFIG_FILE"
}


main
