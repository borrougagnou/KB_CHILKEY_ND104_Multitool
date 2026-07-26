#ifndef HID_PROTOCOL_FOR_WEATHER_HH
#define HID_PROTOCOL_FOR_WEATHER_HH

#include <hidapi.h>
#include "weather_data.hh"

bool send_weather(hid_device *handle, const weather_data *weather);

#endif

