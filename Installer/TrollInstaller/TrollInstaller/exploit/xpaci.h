// ptrauth.h replacement

static uint64_t __attribute((naked)) __xpaci(uint64_t a)
{
    asm(".long        0xDAC143E0"); // XPACI X0
    asm("ret");
}

static uint64_t xpaci(uint64_t a)
{
    // If a looks like a non-pac'd pointer just return it
    if ((a & 0xFFFFFF0000000000) == 0xFFFFFF0000000000)
    {
        return a;
    }
    
    return __xpaci(a);
}
