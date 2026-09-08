#!/bin/sh

#
# To be able to control the keyboard on Linux
# You need to autorize the access to /dev/hidraw
# To do that, execute the script with permission
#

# detect root permission
if [ "$(id -u)" -ne 0 ]; then
    echo "Please run this script as root"
    exit 1
fi

# detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID="$ID"
else
    echo "Cannot detect OS."
    exit 1
fi

echo "==> Detected OS: $OS_ID"



## PART 1
echo "==> Allow communication between the keyboard and Linux"


## https://skia.googlesource.com/external/github.com/libsdl-org/SDL/%2B/refs/heads/main/src/hidapi/udev/69-hid.rules#20
## MORE INFO AT: https://github.com/systemd/systemd/issues/4288#issuecomment-348166161
cat << EOF > /etc/udev/rules.d/70-ubest.rules
# UBEST ND104 Keyboard
KERNEL=="hidraw*", ATTRS{idVendor}=="6d67", ATTRS{idProduct}=="016c", MODE="0666", TAG+="uaccess"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="6d67", ATTRS{idProduct}=="016c", TAG+="uaccess"

# UBEST ND104 Screen
KERNEL=="hidraw*", ATTRS{idVendor}=="5542", ATTRS{idProduct}=="0001", MODE="0666", TAG+="uaccess"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="5542", ATTRS{idProduct}=="0001", TAG+="uaccess"

EOF

## REMOVE PREVIOUS DRIVER IF EXIST:
rm -rf /etc/udev/rules.d/99-ubest.rules

udevadm control --reload-rules
udevadm trigger



## PART 2
echo "==> Install libusb for HID script"

case "$OS_ID" in
  debian|ubuntu|linuxmint|pop|elementary)
    pkg="libusb-1.0-0"
    cmd="apt-get install -y"
    ;;
  fedora)
    pkg="libusb1"
    cmd="dnf install -y"
    ;;
  rhel|centos|rocky|almalinux)
    pkg="libusb1"
    cmd="dnf install -y"
    ;;
  arch|manjaro|endeavouros)
    pkg="libusb"
    cmd="pacman -S --noconfirm"
    ;;
  freebsd)
    pkg="libusb"
    cmd="pkg install -y"
    ;;
  *)
    echo "Unsupported OS: $OS_ID"
    exit 1
    ;;
esac

$cmd $pkg



echo "Script executed successfully"
