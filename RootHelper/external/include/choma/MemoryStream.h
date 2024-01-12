#ifndef MEMORY_STREAM_H
#define MEMORY_STREAM_H

#include <stdio.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <string.h>
#include <unistd.h>
#include <stdbool.h>

#define MEMORY_STREAM_FLAG_OWNS_DATA (1 << 0)
#define MEMORY_STREAM_FLAG_MUTABLE (1 << 1)
#define MEMORY_STREAM_FLAG_AUTO_EXPAND (1 << 2)

#define MEMORY_STREAM_SIZE_INVALID (size_t)-1

// A generic memory IO interface that is used throughout this project
// Can be backed by anything, just the functions have to be implemented
typedef struct s_MemoryStream {
   void *context;
   uint32_t flags;

   int (*read)(struct s_MemoryStream *stream, uint64_t offset, size_t size, void *outBuf);
   int (*write)(struct s_MemoryStream *stream, uint64_t offset, size_t size, const void *inBuf);
   int (*getSize)(struct s_MemoryStream *stream, size_t *sizeOut);
   uint8_t *(*getRawPtr)(struct s_MemoryStream *stream);

   int (*trim)(struct s_MemoryStream *stream, size_t trimAtStart, size_t trimAtEnd);
   int (*expand)(struct s_MemoryStream *stream, size_t expandAtStart, size_t expandAtEnd);

   struct s_MemoryStream *(*hardclone)(struct s_MemoryStream *stream);
   struct s_MemoryStream *(*softclone)(struct s_MemoryStream *stream);
   void (*free)(struct s_MemoryStream *stream);
} MemoryStream;

int memory_stream_read(MemoryStream *stream, uint64_t offset, size_t size, void *outBuf);
int memory_stream_write(MemoryStream *stream, uint64_t offset, size_t size, const void *inBuf);

int memory_stream_insert(MemoryStream *stream, uint64_t offset, size_t size, const void *inBuf);
int memory_stream_delete(MemoryStream *stream, uint64_t offset, size_t size);

int memory_stream_read_string(MemoryStream *stream, uint64_t offset, char **outString);
int memory_stream_write_string(MemoryStream *stream, uint64_t offset, const char *string);

size_t memory_stream_get_size(MemoryStream *stream);
uint8_t *memory_stream_get_raw_pointer(MemoryStream *stream);
uint32_t memory_stream_get_flags(MemoryStream *stream);

MemoryStream *memory_stream_softclone(MemoryStream *stream);
MemoryStream *memory_stream_hardclone(MemoryStream *stream);
int memory_stream_trim(MemoryStream *stream, size_t trimAtStart, size_t trimAtEnd);
int memory_stream_expand(MemoryStream *stream, size_t expandAtStart, size_t expandAtEnd);

void memory_stream_free(MemoryStream *stream);

int memory_stream_copy_data(MemoryStream *originStream, uint64_t originOffset, MemoryStream *targetStream, uint64_t targetOffset, size_t size);
int memory_stream_find_memory(MemoryStream *stream, uint64_t searchStartOffset, uint64_t searchEndOffset, void *bytes, void *mask, size_t nbytes, uint16_t alignment, uint64_t *foundOffsetOut);

#endif // MEMORY_STREAM_H