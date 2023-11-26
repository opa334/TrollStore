#ifndef BASE64_H
#define BASE64_H

#include <stdint.h>
#include <stdlib.h>

char *base64_encode(const unsigned char *data,
                    size_t input_length,
                    size_t *output_length);

#endif // BASE64_H