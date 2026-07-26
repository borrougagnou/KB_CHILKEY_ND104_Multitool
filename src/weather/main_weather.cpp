#include "include/weather_orchestrator.hh"

#include <hidapi.h>

#include <iostream>


int main() {
    const unsigned short vid    = 0x5542;
    const unsigned short pid    = 0x0001;
    hid_device*          handle;
    const wchar_t*       err;

    if (hid_init()) {
        std::cerr << "HID init failed\n";
        return 1;
    }

    handle = hid_open(vid, pid, NULL);
    if (!handle)
    {
        err = hid_error(nullptr);
        if (err)
            std::wcerr << "ERROR: Unable to open device: incorrect permission or " << err << std::endl;
        else
            std::cerr << "ERROR: Unable to open device (unknown): maybe incorrect permission" << std::endl;

        hid_exit();
        return 1;
    }

    if (!update_weather(handle))
    {
        hid_close(handle);
        hid_exit();
        return 1;
    }

    hid_close(handle);
    hid_exit();

    return 0;
}

