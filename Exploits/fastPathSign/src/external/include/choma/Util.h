#include <stdint.h>
#include <stdlib.h>

int memcmp_masked(const void *str1, const void *str2, unsigned char* mask, size_t n);
uint64_t align_to_size(int size, int alignment);
int count_digits(int64_t num);
void print_hash(uint8_t *hash, size_t size);