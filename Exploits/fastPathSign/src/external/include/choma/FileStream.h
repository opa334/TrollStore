#ifndef FILE_STREAM_H
#define FILE_STREAM_H

#include "MemoryStream.h"

#define FILE_STREAM_SIZE_AUTO 0
#define FILE_STREAM_FLAG_WRITABLE (1 << 0)
#define FILE_STREAM_FLAG_AUTO_EXPAND (1 << 1)

typedef struct FileStreamContext {
    int fd;
    size_t fileSize;
    uint32_t bufferStart;
    size_t bufferSize;
} FileStreamContext;

MemoryStream *file_stream_init_from_file_descriptor_nodup(int fd, uint32_t bufferStart, size_t bufferSize, uint32_t flags);
MemoryStream *file_stream_init_from_file_descriptor(int fd, uint32_t bufferStart, size_t bufferSize, uint32_t flags);
MemoryStream *file_stream_init_from_path(const char *path, uint32_t bufferStart, size_t bufferSize, uint32_t flags);

#endif // FILE_STREAM_H