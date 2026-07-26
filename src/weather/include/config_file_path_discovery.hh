#ifndef CONFIG_FILE_PATH_DISCOVERY_HH
#define CONFIG_FILE_PATH_DISCOVERY_HH

#include <string>

struct config_paths {
    std::string configuration;
    std::string ca_certificate;
};

bool get_config_path(const char *config_directory, config_paths *paths, std::string *error_message);

#endif

