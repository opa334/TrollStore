#ifndef BUFFERED_STREAM_H
#define BUFFERED_STREAM_H

#include "MemoryStream.h"
#include <stdbool.h>

#define BUFFERED_STREAM_FLAG_AUTO_EXPAND (1 << 0)

typedef struct BufferedStreamContext {
    uint8_t *buffer;
    size_t bufferSize;
    uint32_t subBufferStart;
    size_t subBufferSize;
} BufferedStreamContext;

MemoryStream *buffered_stream_init_from_buffer_nocopy(void *buffer, size_t bufferSize, uint32_t flags);
MemoryStream *buffered_stream_init_from_buffer(void *buffer, size_t bufferSize, uint32_t flags);

#endif // BUFFERED_STREAM_H