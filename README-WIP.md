
## ⚠️  WIP PART DO NOT TAKE CARE !












## 📦 Installation


---

## ![windows_logo](https://www.readmecodegen.com/api/social-icon?name=windows&size=32) Windows

⚠️ Make sure you know how to open PowerShell (Internet is your friend)

### 🌤️ Weather tool

Run this in PowerShell:

```powershell
powershell -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/borrougagnou/KB_CHILKEY_ND104_Multitool/master/install_weather.ps1' -OutFile '$env:TEMP\install_weather.ps1'; Start-Process PowerShell -Verb RunAs -ArgumentList '-File ""$env:TEMP\install_weather.ps1""'"
```

> [!TIP]
> ❤️ For Windows XP users:
> 1. Download the file `install_weather.ps1` from the repository release page.
> 2. Open a terminal on your computer.
> 3. Run the following command (on CMD or POWERSHELL), replacing `<PATH_TO_FILE>` with the location where you downloaded the file:
> ```powershell
> powershell -ExecutionPolicy Bypass -Command "& '<PATH_TO_FILE>\install_weather.ps1' -TargetUser ([Environment]::UserName) -TargetLocalAppData ([Environment]::GetFolderPath('LocalApplicationData') + '\')"
> ```
> **Example:** If the file is in your Desktop folder:
> ```powershell
> powershell -ExecutionPolicy Bypass -Command "& 'C:\Documents and Settings\user\Desktop\install_weather.ps1' -TargetUser ([Environment]::UserName) -TargetLocalAppData ([Environment]::GetFolderPath('LocalApplicationData') + '\')"
> ```
> 4. Press Enter to start the installation.

### 🧠 What happens after install:
- 📥 Downloads Weather app
- 📁 Installs to: `AppData\Local\Programs\MyProject`
- ⚙️ Creates config in: `AppData\Local\MyProject`
- ⏰ Sets automatic scheduling (runs periodically)


---

## <img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/tux.svg" width="32" height="32"> Linux

⚠️ Make sure you know how to open a terminal

### 🌤️ Weather tool

Choose ONE method:

#### curl :
```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/borrougagnou/KB_CHILKEY_ND104_Multitool/master/install_weather_linux.sh)"
```

#### wget :
```sh
sh -c "$(wget -O- https://raw.githubusercontent.com/borrougagnou/KB_CHILKEY_ND104_Multitool/master/install_weather_linux.sh)"
```

#### fetch :
```sh
sh -c "$(fetch -o - https://raw.githubusercontent.com/borrougagnou/KB_CHILKEY_ND104_Multitool/master/install_weather_linux.sh)"
```

### 🧠 What happens after install:
- 📥 Installs binary to: `$HOME/.local/bin`
- ⚙️ Creates config in: `$HOME/.config/MyProject`
- ⏰ Sets up automatic scheduling


---

## ![apple_logo](https://www.readmecodegen.com/api/social-icon?name=apple&size=32) macOS

⚠️ Make sure you know how to open Terminal (Internet is your friend)

### 🌤️ Weather tool

Choose ONE method:

#### curl :
```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/borrougagnou/KB_CHILKEY_ND104_Multitool/master/install_weather_mac.sh)"
```

#### wget :
```bash
sh -c "$(wget -O- https://raw.githubusercontent.com/borrougagnou/KB_CHILKEY_ND104_Multitool/master/install_weather_mac.sh)"
```

### 🧠 What happens after install:
- 📥 Installs binary to: `$HOME/.local/bin`
- ⚙️ Creates config in: `$HOME/Library/Application Support/MyProject`
- ⏰ Sets up automatic scheduling






























---

## 🚀 How to use

> [!NOTE]
> ℹ️ No admin/root rights needed for normal usage<br />
> 🔐 Permissions are only required for creating a scheduling tasks<br />
> ⚙️ You can re-run the install scripts or edit the config file anytime

---

## 📦 Installation


---

## ![windows_logo](https://www.readmecodegen.com/api/social-icon?name=windows&size=32) Windows

⚠️ Make sure you know how to open PowerShell (Internet is your friend)

### 🌤️ Weather tool

Run this in PowerShell:

```powershell
powershell -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/borrougagnou/KB_CHILKEY_ND104_Multitool/master/install_weather.ps1' -OutFile '$env:TEMP\install_weather.ps1'; Start-Process PowerShell -Verb RunAs -ArgumentList '-File ""$env:TEMP\install_weather.ps1""'"
```

### 🧠 What happens after install:
- 📥 Downloads Weather app
