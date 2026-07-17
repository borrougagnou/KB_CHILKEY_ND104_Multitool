#include "include/clock_update.hh"

#include <cstdint>
#include <iostream>
#include <ctime>
#include <array>
#include <cstddef>


constexpr std::size_t   clock_payload_size = 32;
constexpr std::size_t   hid_report_size    = 65;

constexpr std::uint16_t crc_initial_value  = 0xffff;
constexpr std::uint16_t crc_polynomial     = 0x1021;
constexpr std::uint16_t crc_high_bit       = 0x8000;

enum clock_offset : std::size_t
{
    clock_crc_high  = 0x06,
    clock_crc_low   = 0x07,

    clock_year_high = 0x0e,
    clock_year_low  = 0x0f,
    clock_month     = 0x10,
    clock_day       = 0x11,
    clock_hour      = 0x12,
    clock_minute    = 0x13,
    clock_second    = 0x14,
    clock_weekday   = 0x15,

    clock_checksum       = 0x16,
    clock_checksum_start = 0x09
};



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


bool update_clock(hid_device* handle)
{
    std::time_t   current_time;
    std::tm       local_time;
    std::uint16_t year;
    std::uint16_t checksum_sum;
    std::uint16_t crc;
    std::uint8_t  year_high;
    std::uint8_t  year_low;
    std::uint8_t  month;
    std::uint8_t  day;
    std::uint8_t  hour;
    std::uint8_t  minute;
    std::uint8_t  second;
    std::uint8_t  weekday;
    std::uint8_t  checksum;
    std::array<unsigned char, clock_payload_size> payload;
    std::array<unsigned char, hid_report_size>    hid_report;
    const wchar_t *error;
    std::size_t   index;
    int           result;


    if (!handle)
    {
        std::cerr << "ERROR: Invalid HID handle\n";
        return false;
    }

    current_time = std::time(nullptr);

    if (current_time == static_cast<std::time_t>(-1))
    {
        std::cerr << "ERROR: Unable to read the current time\n";
        return false;
    }

    #if defined(_WIN32)
        if (localtime_s(&local_time, &current_time) != 0)
        {
            std::cerr << "ERROR: Unable to convert the current time\n";
            return false;
        }
    #else
        if (localtime_r(&current_time, &local_time) == nullptr)
        {
            std::cerr << "ERROR: Unable to convert the current time\n";
            return false;
        }
    #endif


    // Prepare the date and time values before creating the payload.
    year      = static_cast<std::uint16_t>(local_time.tm_year + 1900);
    year_high = static_cast<std::uint8_t>((year >> 8) & 0xff);
    year_low  = static_cast<std::uint8_t>(year & 0xff);
    month     = static_cast<std::uint8_t>(local_time.tm_mon + 1);
    day       = static_cast<std::uint8_t>(local_time.tm_mday);
    hour      = static_cast<std::uint8_t>(local_time.tm_hour);
    minute    = static_cast<std::uint8_t>(local_time.tm_min);
    second    = static_cast<std::uint8_t>(local_time.tm_sec);
    weekday   = static_cast<std::uint8_t>(local_time.tm_wday);

    // The checksum covers bytes 0x09 to 0x15.
    // The fixed non-zero values in that range are:
    // 0x38, 0x0a and 0x01.
    checksum_sum =  0x38 + 0x0a + 0x01;
    checksum_sum += year_high;
    checksum_sum += year_low;
    checksum_sum += month;
    checksum_sum += day;
    checksum_sum += hour;
    checksum_sum += minute;
    checksum_sum += second;
    checksum_sum += weekday;

    checksum = static_cast<std::uint8_t>(0xff - (checksum_sum & 0xff));

    // Complete 32-byte device payload.
    // Bytes 0x06 and 0x07 remain zero while calculating the CRC.
    payload =
    {
        /* 0x00 - 0x07 */
        0x1c, 0x03, 0x00, 0x00, 0x00, 0x0f, 0x00, 0x00,

        /* 0x08 - 0x0f */
        0xa5, 0x38, 0x00, 0x0a, 0x00, 0x01, year_high, year_low,

        /* 0x10 - 0x17 */
        month, day, hour, minute, second, weekday, checksum, 0x00,

        /* 0x18 - 0x1f */
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    };

    // Calculate the CRC over the complete 32-byte payload.
    crc = calculate_crc16_ccitt(payload.data(), payload.size());
    // Shift the CRC right by 8 bits (1 byte), isolate the high byte and store it in the payload
    payload[clock_crc_high] = static_cast<std::uint8_t>((crc >> 8) & 0xff);
    // Isolate the low byte of the CRC and store it in the payload
    payload[clock_crc_low] = static_cast<std::uint8_t>(crc & 0xff);

 
    /*
       /!\ HIDAPI reserves byte 0 for the report ID. 
       The device payload starts at hid_report[1].
       The remaining bytes stay zero.
    */
    hid_report.fill(0);
    hid_report[0] = 0x00;

    for (index = 0; index < payload.size(); index++)
        hid_report[index + 1] = payload[index];

    result = hid_write(handle, hid_report.data(), hid_report.size());

    if (result < 0)
    {
        error = hid_error(handle);

        if (error)
            std::wcerr << "ERROR: Unable to update clock: " << error << std::endl;
        else
            std::cerr << "ERROR: Unable to update clock\n";

        return false;
    }

    std::wcerr << "Clock Updated !" << std::endl;
    return true;
}

