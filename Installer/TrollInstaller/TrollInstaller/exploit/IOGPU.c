#include "IOGPU.h"

#include <sys/utsname.h>

io_connect_t IOGPU_init(void)
{
    mach_port_t mp = MACH_PORT_NULL;
    kern_return_t IOMasterPort(mach_port_t, mach_port_t *);
    IOMasterPort(MACH_PORT_NULL, &mp);
    io_connect_t uc;

    io_service_t s = IOServiceGetMatchingService(mp, IOServiceMatching("AGXAccelerator"));
    if (s == MACH_PORT_NULL)
    {
        return 0;
    }
    
    if (IOServiceOpen(s, mach_task_self(), 1, &uc) != KERN_SUCCESS)
    {
        return 0;
    }
    
    return uc;
}

void IOGPU_exit(io_connect_t uc)
{
    IOServiceClose(uc);
}

uint32_t IOGPU_create_command_queue(io_connect_t uc, uint64_t member)
{
    uint64_t outStructCnt = 0x10;
    uint32_t inStructCnt = 0x408;
    uint8_t inStruct[0x408] = {0};
    uint8_t outStruct[0x10] = {0};
    
    // avoid null termination
    memset(inStruct, 0x01, 0x30);
    *(uint64_t *)(inStruct + 0x30) = member;

    kern_return_t kr = IOConnectCallStructMethod(uc, 7, inStruct, inStructCnt, outStruct, (size_t *)&outStructCnt);

    if (kr)
        return 0;
    
    return 1;
}

int IOGPU_get_command_queue_extra_refills_needed(void)
{
    struct utsname u;
    uname(&u);
    
    if (
       strstr(u.machine, "iPod9,") // iPod Touch 7
    || strstr(u.machine, "iPhone9,") // iPhone 7
    || strstr(u.machine, "iPhone12,") // iPhone 11 & SE 2
    || strstr(u.machine, "iPhone13,") // iPhone 12
    || strstr(u.machine, "iPhone14,") // iPhone 13 & SE 3
    || strstr(u.machine, "iPad7,") // iPad7,* has too many different models to list here, see theiphonewiki's "Models" page for info
    || strstr(u.machine, "iPad12,") // iPad 9
    || strstr(u.machine, "iPad13,") // iPad13,1-13,2 is the iPad Air 4 and 13,4-13,11 is the iPad Pro M1.
    || strstr(u.machine, "iPad14,") // iPad Mini 6
    )
    {
        return 1;
    }
    else if (
       strstr(u.machine, "iPhone10,") // iPhone 8, X
    || strstr(u.machine, "iPhone11,") // iPhone XS, XR
    || strstr(u.machine, "iPad8,") // iPad Pro A12Z
    || strstr(u.machine, "iPad11,") // iPad 8 A12
    )
    {
        return 3;
    }
    
    printf("IOGPU_get_command_queue_extra_refills_needed(): Unknown device %s! May panic in generic part until correct number 1-5 is provided for this device!\n", u.machine);
    
    return -1;
}
