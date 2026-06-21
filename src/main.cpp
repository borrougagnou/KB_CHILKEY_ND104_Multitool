#include <iostream>
#include "external/hidapi/hidapi.h"

int main() {
    if (hid_init()) {
        std::cerr << "HID init failed\n";
        return 1;
    }

    unsigned short vid = 0x1234;
    unsigned short pid = 0x5678;

    hid_device* handle = hid_open(vid, pid, NULL);
    if (!handle) {
        std::cerr << "Unable to open device\n";
        return 1;
    }

    unsigned char buf[65] = {0};
    buf[1] = 0x01;

    hid_write(handle, buf, sizeof(buf));

    hid_close(handle);
    hid_exit();

    return 0;
}
