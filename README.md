# ⌨️ Chilkey ND104 Keyboard Tools

### ⚠️  WIP README

Tools designed to extend and automate your Chilkey ND104 keyboard experience.

Here's a list of plugin:

- ✅ : Clock (tested and working on Linux)
- ⏳ : Weather
- ❌ : ...
- ❌ : ...


> [!CAUTION]
>
> ⚠️  **Windows and Mac are not supported yet** (missing tester)
>
> However, The source code includes sections to ensure compatibility with these systems. 


---

## ⚠️ Before you start

- 📖 Read carefuly the **[How to use](#-how-to-use)** section.
- 📜 Licensed under **GPL-3.0** (please respect it)
- 🔌 Requires a **USB-connected ND104 keyboard**

---

## 🐧 Linux setup (required)

> [!INFO]
>
> If you already followed "Firmware Upgrade", you don't need to do this step 

⚠️ Linux users must run this first with **sudo/root permission**

Choose ONE method:

- with **curl**:  `sudo sh -c "$(curl -fsSL https://raw.githubusercontent.com/borrougagnou/KB_CHILKEY_ND104_Multitool/master/install_keyboard_driver.sh)"`
- with **wget**:  `sudo sh -c "$(wget -O-   https://raw.githubusercontent.com/borrougagnou/KB_CHILKEY_ND104_Multitool/master/install_keyboard_driver.sh)"`
- with **fetch**: `sudo sh -c "$(fetch -o - https://raw.githubusercontent.com/borrougagnou/KB_CHILKEY_ND104_Multitool/master/install_keyboard_driver.sh)"`

### What it does:

- 🔗 Enables communication between your Chilkey ND104 keyboard and your system
- 📦 Installs `libusb-1.0-0-dev` (required dependency)

---

## 📖 How to use

### Clock

- Connect the Keyboard in wired mode
- Execute the `clock_update` program (no need admin/root right)
- The program will read the clock on your computer and synchronize it with the keyboard

---
 
## ⚙️ Build
Here's the part for the developper or user who want to install it by themselves:<br />
Install LibUSB on Linux + GCC + Install Make and CMake


### <img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/tux.svg" width="24" height="24"> On Linux
> [!IMPORTANT]
> Please execute the `install_keyboard_driver.sh` first !
> The script will allow communication between your device and your system + will install `libusb-1.0-0-dev` because it is needed for the build OR the execution of the program.

To build the program - 2 choices:
- With Make: execute the command `make` into the root folder with the Makefile

- With CMake:
```
cmake -S . -B cmake-build
cmake --build cmake-build
```


### ![apple_logo](https://www.readmecodegen.com/api/social-icon?name=apple&size=24) On Mac
Build the program with `make` or `cmake`
- With Make: execute the command `make` into the folder with the Makefile

- With CMake:
```
cmake -S . -B cmake-build
cmake --build cmake-build
```


### ![windows_logo](https://www.readmecodegen.com/api/social-icon?name=windows&size=24) On Windows
Build the program with `make` or `cmake`
- With Make: execute the command `make` into the folder with the Makefile

- With CMake:
```
cmake -S . -B cmake-build
cmake --build cmake-build
```


## 🧪 Test:

Tested on Linux: ✅<br />
Tested on MacOS: 🔀 yes but not tested on a real machine<br />
Tested on Windows: 🔀 yes but not tested on a real machine<br />


## ℹ️ Source

The `/src/external` folder contain external source of every project used on the program
