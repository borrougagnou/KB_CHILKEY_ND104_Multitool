# ⌨️ Chilkey ND104 Keyboard Tools

Tools designed to extend and automate your Chilkey ND104 keyboard experience.

Here's a list of plugin:

- ✅ : Clock (tested and working on Linux)
- ⏳ : Weather (2 API at the moment) - cron and task scheduler soon


> [!CAUTION]
>
> ⚠️  **Windows and Mac are supported but not "fully tested"* (missing feedback and other thing)


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


## Manual Installation (all systems):
### Step 1
 - download the binary from the release
 - the config.json `/!\ Modify the content !!! and don't touch "other_weather_api_available"`
 - https://curl.se/ca/cacert.pem

### Step 2
add all of theses file into the corresponding folder:
- Linux: `~/.config/Chilkey_ND104/`
- Mac: `~/Library/Application Support/Chilkey_ND104/`
- Windows: your `AppData\Local\Chilkey_ND104\`

### Step 3
Create a new scheduler:
- Linux:

```
cat > "$HOME/.config/systemd/user/Chilkey_ND104_weather.service" <<EOF_WSERVICE
[Unit]
Description=Chilkey ND104 Weather job

[Service]
Type=oneshot
ExecStart="~/.config/Chilkey_ND104/weather_update-linux-x64"
EOF_WSERVICE


cat > "$HOME/.config/systemd/user/Chilkey_ND104_weather.timer" <<EOF_WTIMER
[Unit]
Description=Run Chilkey ND104 Weather periodically

[Timer]
OnStartupSec=30s
OnUnitActiveSec=30min
Unit=Chilkey_ND104_weather.service

[Install]
WantedBy=timers.target
EOF_WTIMER

cat > "$HOME/.config/systemd/user/Chilkey_ND104_clock.service" <<EOF_CSERVICE
[Unit]
Description=Chilkey ND104 Clock job

[Service]
Type=oneshot
ExecStart="~/.config/Chilkey_ND104/clock_update-linux-x64"
EOF_CSERVICE


cat > "$HOME/.config/systemd/user/Chilkey_ND104_clock.timer" <<EOF_CTIMER
[Unit]
Description=Run Chilkey ND104 Clock periodically

[Timer]
OnStartupSec=30s
OnUnitActiveSec=6h
Unit=Chilkey_ND104_clock.service

[Install]
WantedBy=timers.target
EOF_CTIMER
```

Then:
```
systemctl --user daemon-reload
systemctl --user enable --now "Chilkey_ND104_weather.timer" 
systemctl --user enable --now "Chilkey_ND104_clock.timer" 
```

- Mac (just copy paste into a terminal and press enter):

```
xml_escape() {
    printf '%s' "$1" | sed \
        -e 's/&/\&amp;/g' \
        -e 's/</\&lt;/g' \
        -e 's/>/\&gt;/g' \
        -e 's/"/\&quot;/g'
}

escaped_wprogram=$(xml_escape "$HOME/Library/Application Support/Chilkey_ND104/weather_update-mac")
cat > "$HOME/Library/LaunchAgents/com.chilkeynd104.chilkeynd104weather.plist" <<EOF_WPLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.chilkeynd104.chilkeynd104weather</string>

    <key>ProgramArguments</key>
    <array>
        <string>$escaped_wprogram</string>
    </array>

    <key>RunAtLoad</key>
    <true/>

    <key>StartInterval</key>
    <integer>1800</integer>
</dict>
</plist>
EOF_WPLIST

escaped_cprogram=$(xml_escape "$HOME/Library/Application Support/Chilkey_ND104/clock_update-mac")
cat > "$HOME/Library/LaunchAgents/com.chilkeynd104.chilkeynd104clock.plist" <<EOF_CPLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.chilkeynd104.chilkeynd104clock</string>

    <key>ProgramArguments</key>
    <array>
        <string>$escaped_cprogram</string>
    </array>

    <key>RunAtLoad</key>
    <true/>

    <key>StartInterval</key>
    <integer>18000</integer>
</dict>
</plist>
EOF_CPLIST
```

Then:
```
uid=$(id -u)
launchctl bootout "gui/$uid/com.chilkeynd104.chilkeynd104weather"
launchctl bootstrap "gui/$uid" "$$HOME/Library/LaunchAgents/com.chilkeynd104.chilkeynd104weather.plist"
launchctl bootout "gui/$uid/com.chilkeynd104.chilkeynd104clock"
launchctl bootstrap "gui/$uid" "$$HOME/Library/LaunchAgents/com.chilkeynd104.chilkeynd104clock.plist"
```

- Windows: 

Open the `Task Scheduler` and create a new Task

- Executable Path: your `AppData\Local\Chilkey_ND104\weather_update-win64.exe`
- Execute every: 30min

Create another new Task:
- Executable Path: your `AppData\Local\Chilkey_ND104\clock_update-win64.exe`
- Execute every: 5 hours

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

