#include "include/weather_update.hh"

#include <cstddef>
#include <cstdint>
#include <iomanip>
#include <iostream>


enum weather_icon : std::uint8_t {
    weather_sunny          = 0x00,
    weather_heavy_clouds   = 0x01, // same
    weather_overcast       = 0x01, // same
    weather_partly_cloudy  = 0x02,
    weather_cloudy         = 0x03,
    weather_rain           = 0x04,
    weather_snow           = 0x05,
    weather_clear_night    = 0x06,
    weather_cloudy_night   = 0x07,
    weather_fog            = 0x08,
    weather_thunderstorm   = 0x09
};

constexpr std::size_t   weather_header_size  = 10;
constexpr std::size_t   weather_payload_size = 32;

constexpr unsigned char weather_header[weather_header_size] = {
    0x1c, // offset: 0x00
    0x02, // offset: 0x01
    0x00, // offset: 0x02
    0x00, // offset: 0x03
    0x00, // offset: 0x04
    0x0d, // offset: 0x05 - Payload length? (13 decimal)
    0x00, // offset: 0x06 - CRC low  --> calculated later
    0x00, // offset: 0x07 - CRC high --> calculated later
    0xa5, // offset: 0x08 - Magic
    0xfe  // offset: 0x09 - Report ID
};

enum weather_offset : std::size_t {
    weather_crc_low_offset             = 0x06, // CRC-16/CCITT-FALSE - low byte
    weather_crc_high_offset            = 0x07, // CRC-16/CCITT-FALSE - high byte
    weather_magic_offset               = 0x08,
    weather_report_id_offset           = 0x09,
    weather_reserved_1_offset          = 0x0a,
    weather_data_length_offset         = 0x0b,
    weather_reserved_2_offset          = 0x0c,
    weather_icon_offset                = 0x0d,
    weather_current_temperature_offset = 0x0e,
    weather_maximum_temperature_offset = 0x10,
    weather_minimum_temperature_offset = 0x12,
    weather_checksum_offset            = 0x14, // 8‑bit checksum
    weather_padding_offset             = 0x15  // from 0x15 to 0x1F
};

struct weather_data {
    weather_icon icon;
    std::int16_t current_temperature;
    std::int16_t maximum_temperature;
    std::int16_t minimum_temperature;
};

constexpr std::size_t   weather_hid_report_size = weather_payload_size + 1;
constexpr unsigned char weather_hid_report_id   = 0x00;
constexpr unsigned char weather_checksum_target = 0x01;

constexpr std::uint16_t crc_initial_value   = 0xffff;
constexpr std::uint16_t crc_polynomial      = 0x1021;
constexpr std::uint16_t crc_high_bit        = 0x8000;


//==========CHECKSUM PART

/*
   CRC = Cyclic Redundancy Check.

   We need to creates a 16-bit value from the packet content so the device
   can detect whether the packet was damaged or incorrectly constructed.
  
   This implements CRC-16/CCITT-FALSE:
   - initial value: 0xffff
   - polynomial:    0x1021
   - no final XOR
*/
std::uint16_t calculate_crc16_ccitt(const unsigned char* data, std::size_t size)
{
    std::uint16_t crc;
    std::size_t   byte_index;
    std::uint8_t  bit_index;
    std::uint16_t current_byte;
    std::uint16_t shifted_byte;
    bool          msb_is_set; // Most Significant Bit 

    crc = crc_initial_value;

    for (byte_index = 0; byte_index < size; byte_index++)
    {
        // Read a byte, Convert it to a 16-bit value, Move it into the high byte, XOR it into the CRC.
        current_byte = static_cast<std::uint16_t>(data[byte_index]);
        shifted_byte = current_byte << 8;
        crc ^= shifted_byte;

        for (bit_index = 0; bit_index < 8; bit_index++)
        {
            /*
               0x8000 represents the highest bit of a 16-bit value.
               "crc & 0x8000" checks whether that highest bit is set
               before shifting the CRC to the left.
               1. Remember whether the MSB was set.
               2. Shift left.
               3. If the MSB was set, XOR with the polynomial.
            */

            msb_is_set = (crc & crc_high_bit) != 0;
            crc = static_cast<std::uint16_t>(crc << 1);
            if (msb_is_set)
            {
                crc ^= crc_polynomial;
            }
            //if ((crc & crc_high_bit) != 0)
            //    crc = static_cast<std::uint16_t>((crc << 1) ^ crc_polynomial);
            //else
            //    crc = static_cast<std::uint16_t>(crc << 1);
        }
    }

    return crc;
}

/*
   Calculate the packet's 8-bit additive checksum.

   The checksum is computed by:
   - summing all protected payload bytes;
   - keeping only the low 8 bits of the sum;
   - subtracting that value from the checksum target.

   Formula:
       checksum = target - (sum & 0xff)

   This allows the receiver to verify the packet by summing the bytes and
   checking that the result matches the expected target.
*/
static unsigned char calculate_weather_checksum(const unsigned char* payload)
{
    unsigned int sum;
    std::size_t  offset;

    sum = 0;

    for (offset = weather_report_id_offset; offset < weather_payload_size; ++offset)
        sum += payload[offset];

    // keeps only the lowest 8 bits of sum, effectively calculating sum mod 256 for non-negative values
    return static_cast<unsigned char>((sum ^ 0xffu) & 0xffu);
}

//==========BUILD AND WRITING PART

static void write_temperature(unsigned char* payload, std::size_t offset, std::int16_t temperature)
{
    std::uint16_t encoded_temperature;
    std::int32_t absolute_temperature;

    // If temperature is negative, store as `32768 + abs(temp)` (which is the same as signed 16-bit representation).
    // 32768 = 0x8000 hex
    if (temperature < 0)
    {
        absolute_temperature = -static_cast<std::int32_t>(temperature);
        encoded_temperature = static_cast<std::uint16_t>(0x8000 + absolute_temperature);
    }
    else
        encoded_temperature = static_cast<std::uint16_t>(temperature);

    payload[offset]     = static_cast<unsigned char>((encoded_temperature >> 8) & 0xffu);
    payload[offset + 1] = static_cast<unsigned char>(encoded_temperature & 0xffu);
}

static void build_weather_payload(unsigned char* payload, const weather_data* weather)
{
    std::uint16_t crc;
    std::size_t offset;

    // Reset the payload to 0x00 (in case there's old value into it)
    for (offset = 0; offset < weather_payload_size; ++offset)
        payload[offset] = 0x00;

    // Add the Weather Header into the payload - offset: 0x00->0x09
    for (offset = 0; offset < weather_header_size; ++offset)
        payload[offset] = weather_header[offset];

    payload[weather_reserved_1_offset]  = 0x00; // offset: 0x0A
    payload[weather_data_length_offset] = 0x08; // offset: 0x0B
    payload[weather_reserved_2_offset]  = 0x00; // offset: 0x0C

    payload[weather_icon_offset] = static_cast<unsigned char>(weather->icon); // offset: 0x0D

    write_temperature(payload, weather_current_temperature_offset, weather->current_temperature); // offset: 0x0E/0x0F
    write_temperature(payload, weather_maximum_temperature_offset, weather->maximum_temperature); // offset: 0x10/0x11
    write_temperature(payload, weather_minimum_temperature_offset, weather->minimum_temperature); // offset: 0x12/0x13

    /*
       The CRC is calculated while:
       - CRC low byte is 0x00  - offset: 0x06
       - CRC high byte is 0x00 - offset: 0x07
       - checksum byte is 0x00 - offset: 0x14
    */
    payload[weather_crc_low_offset]  = 0x00;
    payload[weather_crc_high_offset] = 0x00;
    payload[weather_checksum_offset] = 0x00; 

    crc = calculate_crc16_ccitt(payload, weather_payload_size);
    payload[weather_crc_low_offset]  = static_cast<unsigned char>(crc & 0xffu);
    payload[weather_crc_high_offset] = static_cast<unsigned char>((crc >> 8) & 0xffu);

    /*
       The checksum is calculated after the CRC is stored.
       Its range begins at offset 0x09, so the CRC bytes
       are not included.
    */
    payload[weather_checksum_offset] = calculate_weather_checksum(payload);
}

#if DEBUG
static void debug_print_buffer(const char* name, const unsigned char* buffer, std::size_t size)
{
    std::size_t offset;

    std::cout << name << ':';
    std::cout << std::hex << std::setfill('0');

    for (offset = 0; offset < size; ++offset)
        std::cout << ' ' << std::setw(2) << static_cast<unsigned int>(buffer[offset]);

    std::cout << std::dec << std::setfill(' ') << std::endl;
}
#endif

bool update_weather(hid_device* handle)
{
    std::size_t         offset;
    int                 written;
    unsigned char       payload[weather_payload_size];
    unsigned char       hid_report[weather_hid_report_size];
    const wchar_t       *error;

#if DEBUG
    weather_data            test_weather;

    //////CHECKSUM: CALCULATED=0x9C ACCEPTED=0x9C
    constexpr unsigned char expected_test_checksum = 0x9c;
    constexpr std::uint16_t expected_test_crc      = 0xbbe1;
    test_weather.icon                = weather_snow;
    test_weather.current_temperature = 200;
    test_weather.maximum_temperature = 200;
    test_weather.minimum_temperature = 200;

    //////CHECKSUM: CALCULATED=0x9f  ACCEPTED=0x9f
    //constexpr unsigned char expected_test_checksum = 0x9f;
    //constexpr std::uint16_t expected_test_crc      = 0x81fe;
    //test_weather.icon                = weather_partly_cloudy;
    //test_weather.current_temperature = 200;
    //test_weather.maximum_temperature = 200;
    //test_weather.minimum_temperature = 200;

    //////CHECKSUM: CALCULATED=0xd4 ACCEPTED=0xd4
    //constexpr unsigned char expected_test_checksum = 0xd4;
    //constexpr std::uint16_t expected_test_crc      = 0x4c2c;
    //test_weather.icon                = weather_partly_cloudy;
    //test_weather.current_temperature = 270;
    //test_weather.maximum_temperature = 294;
    //test_weather.minimum_temperature = 237;

    //////CHECKSUM: CALCULATED=0xcd ACCEPTED=0xcd
    //constexpr unsigned char expected_test_checksum = 0xcd;
    //constexpr std::uint16_t expected_test_crc      = 0xae12;
    //test_weather.icon                = weather_thunderstorm;
    //test_weather.current_temperature = 270;
    //test_weather.maximum_temperature = 294;
    //test_weather.minimum_temperature = 237;

    //////CHECKSUM: CALCULATED=0x52 ACCEPTED=0x6812
    //constexpr unsigned char expected_test_checksum = 0x52;
    //constexpr std::uint16_t expected_test_crc      = 0x6812;
    //test_weather.icon                = weather_snow;
    //test_weather.current_temperature = -52; // -5.2°C
    //test_weather.maximum_temperature = 23;  //  2.3°C
    //test_weather.minimum_temperature = -87; // -8.7°C

    build_weather_payload(payload, &test_weather);

    std::uint16_t calculated_crc;
    calculated_crc = static_cast<std::uint16_t>(payload[weather_crc_low_offset]);
    calculated_crc |= static_cast<std::uint16_t>(static_cast<std::uint16_t>(payload[weather_crc_high_offset]) << 8);

    if (calculated_crc != expected_test_crc)
    {
        std::cerr
            << "ERROR: Incorrect CRC: expected 0x"
            << std::hex
            << expected_test_crc
            << ", calculated 0x"
            << calculated_crc
            << std::dec
            << std::endl;
        return false;
    }

    if (payload[weather_checksum_offset] != expected_test_checksum)
    {
        std::cerr
            << "ERROR: Incorrect checksum: expected 0x"
            << std::hex
            << static_cast<unsigned int>(expected_test_checksum)
            << ", calculated 0x"
            << static_cast<unsigned int>(payload[weather_checksum_offset])
            << std::dec
            << std::endl;

        return false;
    }
#else
    // WE WILL SEND DATA HERE !!
    // HERE AN EXAMPLE :
    weather_data weather;
    weather.icon                = weather_snow;
    weather.current_temperature = -10;
    weather.maximum_temperature = 999;
    weather.minimum_temperature = -999;
    build_weather_payload(payload, &weather);
#endif

    // HIDAPI explicitly requires the report ID as the first byte, including 0x00 for devices without numbered reports
    hid_report[0] = 0x00;

    for (offset = 0; offset < weather_payload_size; ++offset)
        hid_report[offset + 1] = payload[offset];

#if DEBUG
    debug_print_buffer("Weather protocol payload", payload, weather_payload_size);
    debug_print_buffer("Complete HID report", hid_report, weather_hid_report_size);
#endif

    written = hid_write(handle, hid_report, weather_hid_report_size);
    if (written < 0)
    {
        error = hid_error(handle);

        if (error)
            std::wcerr << "ERROR: Unable to send weather report: " << error << std::endl;
        else
            std::cerr << "ERROR: Unable to send weather report\n" << std::endl;

        return false;
    }

    if (written != static_cast<int>(weather_hid_report_size))
    {
        std::cerr
            << "ERROR: Incomplete HID report: "
            << written
            << " of "
            << weather_hid_report_size
            << " bytes written"
            << std::endl;

        return false;
    }

#if DEBUG
    std::cout << "Weather test HID report written successfully: " << written << " bytes" << std::endl;
#endif

    return true;
}
