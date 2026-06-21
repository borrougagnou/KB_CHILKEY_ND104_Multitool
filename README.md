# CPPHID_Multiplatform
test and experiment a CPP program compatible for Windows, Mac, Linux with HID compatibility


## Requirement:
Maybe the GCC version ? + Install Make and CMake ?


## Build:

### On Linux

> [!IMPORTANT]
> Please execute the `install_keyboard_driver.sh` first !
> The script will allow communication between your device and your system + will install `libusb-1.0-0-dev` because it is needed for the build OR the execution of the program.

To build the program: 2 choices:
- With Make: execute the command `make` into the folder with the Makefile

- With CMake:
```
mkdir build && cd build
cmake ..
cmake --build .
```


### On Mac:
Build the program with `make` or `cmake`
- With Make: execute the command `make` into the folder with the Makefile

- With CMake:
```
mkdir build && cd build
cmake ..
cmake --build .
```


### On Windows:
Build the program with `make` or `cmake`
- With Make: execute the command `make` into the folder with the Makefile

- With CMake:
```
mkdir build && cd build
cmake ..
cmake --build .
```


## Test:

Tested on Linux: ✅<br>
Tested on MacOS: 🔀 yes but not tested on a real machine<br>
Tested on Windows: 🔀 yes but not tested on a real machine<br>


## Source

The `/src/external` folder contain source of every project used on the program
