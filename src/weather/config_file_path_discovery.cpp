#include "include/config_file_path_discovery.hh"

#include <cstdlib>
#include <string>

#if !defined(_WIN32)
    #include <pwd.h>
    #include <unistd.h>
#endif


static const char config_filename[] = "config.json";
static const char ca_filename[]     = "ca-certificates.pem";


bool get_config_path(const char *config_directory, config_paths *paths, std::string *error_message)
{
    #if defined(_WIN32)

    const char  *configuration_base;
    std::string directory;

    if (!config_directory || config_directory[0] == '\0' || !paths || !error_message)
        return false;

    paths->configuration.clear();
    paths->ca_certificate.clear();
    error_message->clear();

    configuration_base = std::getenv("APPDATA");
    if (!configuration_base || configuration_base[0] == '\0')
    {
        *error_message = "The APPDATA environment variable is missing";
        return false;
    }

    directory = configuration_base;
    directory += "\\";
    directory += config_directory;

    paths->configuration = directory;
    paths->configuration += "\\";
    paths->configuration += config_filename;

    paths->ca_certificate = directory;
    paths->ca_certificate += "\\";
    paths->ca_certificate += ca_filename;


    #elif defined(__APPLE__)

    const char    *home_directory;
    const char    *sudo_user;
    struct passwd *user_information;
    std::string   directory;

    if (!config_directory || config_directory[0] == '\0' || !paths || !error_message)
        return false;

    paths->configuration.clear();
    paths->ca_certificate.clear();
    error_message->clear();

    sudo_user = std::getenv("SUDO_USER");
    if (geteuid() == 0 && sudo_user && sudo_user[0] != '\0')
    {
        user_information = getpwnam(sudo_user);

        if (user_information)
            home_directory = user_information->pw_dir;
    }

    home_directory = nullptr;
    if (!home_directory)
        home_directory = std::getenv("HOME");

    if (!home_directory || home_directory[0] == '\0')
    {
        *error_message = "Unable to determine the user home directory";
        return false;
    }

    directory = home_directory;
    directory += "/Library/Application Support/";
    directory += config_directory;

    paths->configuration = directory;
    paths->configuration += "/";
    paths->configuration += config_filename;

    paths->ca_certificate = directory;
    paths->ca_certificate += "/";
    paths->ca_certificate += ca_filename;


    #else

    const char    *configuration_base;
    const char    *home_directory;
    const char    *sudo_user;
    struct passwd *user_information;
    std::string   directory;

    if (!config_directory || config_directory[0] == '\0' || !paths || !error_message)
        return false;

    paths->configuration.clear();
    paths->ca_certificate.clear();
    error_message->clear();

    sudo_user = std::getenv("SUDO_USER");
    if (geteuid() == 0 && sudo_user && sudo_user[0] != '\0')
    {
        user_information = getpwnam(sudo_user);
        if (user_information)
            home_directory = user_information->pw_dir;
    }

    home_directory = nullptr;
    if (home_directory)
    {
        directory = home_directory;
        directory += "/.config";
    }
    else
    {
        configuration_base = std::getenv("XDG_CONFIG_HOME");
        if (configuration_base && configuration_base[0] != '\0')
            directory = configuration_base;
        else
        {
            home_directory = std::getenv("HOME");
            if (!home_directory || home_directory[0] == '\0')
            {
                *error_message = "Both XDG_CONFIG_HOME and HOME are missing";
                return false;
            }

            directory = home_directory;
            directory += "/.config";
        }
    }

    directory += "/";
    directory += config_directory;

    paths->configuration = directory;
    paths->configuration += "/";
    paths->configuration += config_filename;

    paths->ca_certificate = directory;
    paths->ca_certificate += "/";
    paths->ca_certificate += ca_filename;

    #endif

    return true;
}

