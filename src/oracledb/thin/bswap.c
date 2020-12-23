//-----------------------------------------------------------------------------
// Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
// bswap.c
//   These routines are intended to convert from the host format to LSB (least
// significant byte first) and MSB (most significant byte first). Since this is
// not standardized on all platforms, existing capabilities on some platforms
// are not used and the code is written out from scratch.
//-----------------------------------------------------------------------------

#include <stdint.h>

// determine endianness of platform
#if defined(__linux__) || defined(__CYGWIN__)
    #include <endian.h>
#elif defined(__APPLE__)
    #include <machine/endian.h>
#elif defined(_WIN32)
    #define __LITTLE_ENDIAN 1234
    #define __BIG_ENDIAN 4321
    #define __BYTE_ORDER __LITTLE_ENDIAN
#endif


// define macros for swapping, depending on the endianness of the platform
#if __BYTE_ORDER == __BIG_ENDIAN

    #define host_to_msb_16(x)           (x)
    #define host_to_msb_32(x)           (x)
    #define host_to_msb_64(x)           (x)
    #define msb_to_host_16(x)           (x)
    #define msb_to_host_32(x)           (x)
    #define msb_to_host_64(x)           (x)

    #define host_to_lsb_16(x)           bswap16(x)
    #define host_to_lsb_32(x)           bswap32(x)
    #define host_to_lsb_64(x)           bswap64(x)
    #define lsb_to_host_16(x)           bswap16(x)
    #define lsb_to_host_32(x)           bswap32(x)
    #define lsb_to_host_64(x)           bswap64(x)

#elif __BYTE_ORDER == __LITTLE_ENDIAN

    #define host_to_msb_16(x)           bswap16(x)
    #define host_to_msb_32(x)           bswap32(x)
    #define host_to_msb_64(x)           bswap64(x)
    #define msb_to_host_16(x)           bswap16(x)
    #define msb_to_host_32(x)           bswap32(x)
    #define msb_to_host_64(x)           bswap64(x)

    #define host_to_lsb_16(x)           (x)
    #define host_to_lsb_32(x)           (x)
    #define host_to_lsb_64(x)           (x)
    #define lsb_to_host_16(x)           (x)
    #define lsb_to_host_32(x)           (x)
    #define lsb_to_host_64(x)           (x)

#else
    #error Unsupported or unknown byte order.
#endif

#define BYTE_ORDER_LSB                  1
#define BYTE_ORDER_MSB                  2

static inline uint16_t bswap16(uint16_t value)
{
    return ((value << 8) & 0xff00) | ((value >> 8) & 0x00ff);
}


static inline uint32_t bswap32(uint32_t value)
{
    return (
            ((value << 24) & 0xff000000) |
            ((value << 8) & 0x00ff0000) |
            ((value >> 8) & 0x0000ff00) |
            ((value >> 24) & 0x000000ff)
    );
}


static inline uint64_t bswap64(uint64_t value)
{
    return (
        ((value << 56) & 0xff00000000000000ULL) |
        ((value << 40) & 0x00ff000000000000ULL) |
        ((value << 24) & 0x0000ff0000000000ULL) |
        ((value << 8) & 0x000000ff00000000ULL) |
        ((value >> 8) & 0x00000000ff000000ULL) |
        ((value >> 24) & 0x0000000000ff0000ULL) |
        ((value >> 40) & 0x000000000000ff00ULL) |
        ((value >> 56) & 0x00000000000000ffULL)
    );
}


static inline void pack_uint16(unsigned char *buf, uint16_t value, int order)
{
    uint16_t network_value = (order == BYTE_ORDER_MSB) ?
            host_to_msb_16(value) : host_to_lsb_16(value);
    memcpy(buf, &network_value, sizeof(uint16_t));
}


static inline void pack_uint32(unsigned char *buf, uint32_t value, int order)
{
    uint32_t network_value = (order == BYTE_ORDER_MSB) ?
            host_to_msb_32(value) : host_to_lsb_32(value);
    memcpy(buf, &network_value, sizeof(uint32_t));
}


static inline void pack_uint64(unsigned char *buf, uint64_t value, int order)
{
    uint64_t network_value = (order == BYTE_ORDER_MSB) ?
            host_to_msb_64(value) : host_to_lsb_64(value);
    memcpy(buf, &network_value, sizeof(uint64_t));
}


static inline uint16_t unpack_uint16(const unsigned char *buf, int order)
{
    uint16_t network_value;
    memcpy((char*) &network_value, buf, sizeof(uint16_t));
    return (order == BYTE_ORDER_MSB) ?
            msb_to_host_16(network_value) : lsb_to_host_16(network_value);
}


static inline uint32_t unpack_uint32(const unsigned char *buf, int order)
{
    uint32_t network_value;
    memcpy((char*) &network_value, buf, sizeof(uint32_t));
    return (order == BYTE_ORDER_MSB) ?
            msb_to_host_32(network_value) : lsb_to_host_32(network_value);
}


static inline uint64_t unpack_uint64(const unsigned char *buf, int order)
{
    uint64_t network_value;
    memcpy((char*) &network_value, buf, sizeof(uint64_t));
    return (order == BYTE_ORDER_MSB) ?
            msb_to_host_64(network_value) : lsb_to_host_64(network_value);
}
