#ifndef __IOGPU_H__
#define __IOGPU_H__

#include "iokit.h"

#include <mach/mach.h>
#include <stdint.h>

io_connect_t IOGPU_init(void);
void IOGPU_exit(io_connect_t uc);

uint32_t IOGPU_create_command_queue(io_connect_t uc, uint64_t member);

int IOGPU_get_command_queue_extra_refills_needed(void);

#endif
