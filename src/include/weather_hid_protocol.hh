#ifndef WEATHER_HID_PROTOCOL_HH
#define WEATHER_HID_PROTOCOL_HH

#include "../external/hidapi/hidapi.h"
#include "weather_data.hh"

bool send_weather(hid_device *handle, const weather_data *weather);

#endif

