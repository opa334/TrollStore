#ifndef UTIL_H
#define UTIL_H

#include <stdint.h>
#include <stdlib.h>
#include <stdbool.h>

typedef struct s_optional_uint64 {
	bool isSet;
	uint64_t value;
} optional_uint64_t;
#define OPT_UINT64_IS_SET(x) (x.isSet)
#define OPT_UINT64_GET_VAL(x) (x.value)
#define OPT_UINT64_NONE (optional_uint64_t){.isSet = false, .value = 0}
#define OPT_UINT64(x) (optional_uint64_t){.isSet = true, .value = x}


typedef struct s_optional_bool {
	bool isSet;
	bool value;
} optional_bool;
#define OPT_BOOL_IS_SET(x) (x.isSet)
#define OPT_BOOL_GET_VAL(x) (x.value)
#define OPT_BOOL_NONE (optional_bool){.isSet = false, .value = false}
#define OPT_BOOL(x) (optional_bool){.isSet = true, .value = x}

int64_t sxt64(int64_t value, uint8_t bits);
int memcmp_masked(const void *str1, const void *str2, unsigned char* mask, size_t n);
uint64_t align_to_size(int size, int alignment);
int count_digits(int64_t num);
void print_hash(uint8_t *hash, size_t size);
void enumerate_range(uint64_t start, uint64_t end, uint16_t alignment, size_t nbytes, bool (^enumerator)(uint64_t cur));

#endif