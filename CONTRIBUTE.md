## ⚙️ Build and contribution:

Here's the part for the developper or user who want to install it by themselves:<br />


### <img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/tux.svg" width="24" height="24"> On Linux
> [!IMPORTANT]
>
> Please execute the `SETUP.sh` first ! and install the driver. (JSON isn't mandatory for things not related to the weather plugin)
> The script will allow communication between your device and your system + will install `libusb-1.0-0-dev` because it is needed for the build OR the execution of the program.

Also install gcc, g++, make, cmake

To build the program - 2 choices:
- With Make: execute the command `make` into the root folder with the Makefile

- With CMake:
```
cmake -S . -B cmake-build
cmake --build cmake-build
```


### ![apple_logo](https://www.readmecodegen.com/api/social-icon?name=apple&size=24) On Mac
> [!IMPORTANT]
>
> Execute the `SETUP.sh` and install the JSON part if you need to work on the weather plugin part.


Build the program with `make` or `cmake`
- With Make: execute the command `make` into the folder with the Makefile

- With CMake:
```
cmake -S . -B cmake-build
cmake --build cmake-build
```


### ![windows_logo](https://www.readmecodegen.com/api/social-icon?name=windows&size=24) On Windows

> [!CAUTION]
>
> Not Tested yet

Build the program with `make` or `cmake`
- With Make: execute the command `make` into the folder with the Makefile

- With CMake:
```
cmake -S . -B cmake-build
cmake --build cmake-build
```

---
### ☁️  Weather

To Implement a new weather source, Look at the commit : `902afb928aeef8a4c7c4a20114d509c472afa2bf` (New Weather API - Meletrix)

And look at the **weather_data.hh** for `enum` value.


The weather part works like this:

To begin with, there's an Orchestrator who will manage each and every steps.

- the program will search the HOME USER FOLDER (depending on the Operating System Windows/mac/Linux)
- Then, he will read the json file
- ` Weather.geolocation `:
  - if geolocation to true: REQUEST to ` ip-api.com ` our actual location
  - if false: Read the ` Information ` from the JSON file.
- After, it will read the ` Weather.weather_api `, and execute the weather source file corresponding
  - Into the weather source, it will translate the needed value from the website/API into value needed by the keyboard
  - you can use the ` get_http_response() ` from the **http_request.hh** to have data. 
- At the end, it will send the translated value to the Keyboard



## 🧪 Test:

Tested on Linux:   ✅<br />
Tested on MacOS:   🔀 yes but not tested on a real machine<br />
Tested on Windows: 🔀 yes but not tested on a real machine<br />

