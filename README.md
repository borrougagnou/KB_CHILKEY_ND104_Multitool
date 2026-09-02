# ⌨️ Chilkey ND104 Keyboard Tools

Tools designed to extend and automate your Chilkey ND104 keyboard experience.

Here's a list of plugin:

- ✅ : Clock (tested and working on Linux)
- ⏳ : Weather (2 API at the moment) - cron and task scheduler soon
- ❌ : ...
- ❌ : ...


> [!CAUTION]
>
> ⚠️  **Windows and Mac are not supported yet** (missing tester)
>
> However, The source code includes sections to ensure compatibility with these systems.


---

## ⚠️ Before you start

- 📜 Licensed under **GPL-3.0** (please respect it)
- 🔌 Requires a **USB-connected ND104 keyboard**

---

## Install or Update:

## 🐧 Linux setup

⚠️ **sudo/root permission** are requested only for the Driver and the Weather part.

Choose ONE method:

- with **curl**:  `bash -c "$(curl -fsSL https://raw.githubusercontent.com/borrougagnou/KB_CHILKEY_ND104_Multitool/master/SETUP.sh)"`
- with **wget**:  `bash -c "$(wget -O-   https://raw.githubusercontent.com/borrougagnou/KB_CHILKEY_ND104_Multitool/master/SETUP.sh)"`
- with **fetch**: `bash -c "$(fetch -o - https://raw.githubusercontent.com/borrougagnou/KB_CHILKEY_ND104_Multitool/master/SETUP.sh)"`

### What it does:

- 🔗 Enables communication between your Chilkey ND104 keyboard and your system
- 📦 Installs `libusb-1.0-0-dev` (required dependency)
- 🛠️ Create a JSON config file on your home directory
- 📩 Download HTTPS Certificate

## 🍎 Mac setup (not tested)

- Read the Linux setup

## 🪟 Windows setup (not fully implemented)

- Not implemented yet

---

## 📖 How to use

### Clock

- Connect the Keyboard in wired mode
- Execute the `clock_update` program (no need admin/root right)
- The program will read the clock on your computer and synchronize it with the keyboard


### Weather

- Connect the Keyboard in wired mode
- Connect internet.
- Execute the `weather_update` program (no need admin/root right)
- The program will search the config file with parameters

> [!TIPS]
>
> You can change the `weather_api` on the config file by one of the other available api (`other_weather_api_available`)




---

## ⚙️ Build and contribution:


Read the [CONTRIBUTE.md](CONTRIBUTE.md)

