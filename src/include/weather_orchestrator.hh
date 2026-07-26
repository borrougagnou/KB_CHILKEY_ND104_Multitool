#ifndef WEATHER_ORCHESTRATOR_HH
#define WEATHER_ORCHESTRATOR_HH

#include "../external/hidapi/hidapi.h"

bool update_weather(hid_device* handle);

#endif

