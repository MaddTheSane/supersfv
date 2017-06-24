#ifndef __CRC32_H__
#define __CRC32_H__

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#ifndef __private_extern
#define __private_extern __attribute__((visibility("hidden")))
#endif

typedef uint32_t crc32_t;
#define Z_NULL  0u

#define crc32 uulib_crc32

/*!
     Update a running crc with the bytes buf[0..len-1] and return the updated
   crc. If buf is NULL, this function returns the required initial value
   for the crc. Pre- and post-conditioning (one's complement) is performed
   within this function so it shouldn't be done by the application.
   Usage example:

     uLong crc = crc32(0L, Z_NULL, 0);

     while (read_buffer(buffer, length) != EOF) {
       crc = crc32(crc, buffer, length);
     }
     if (crc != original_crc) error();
*/
__private_extern crc32_t crc32(crc32_t crc, const unsigned char *buf, size_t len);

#ifdef __cplusplus
}
#endif
#endif
