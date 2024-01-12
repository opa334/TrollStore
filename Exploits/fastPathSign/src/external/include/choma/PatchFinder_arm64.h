#ifndef PATCHFINDER_ARM64_H
#define PATCHFINDER_ARM64_H

#include "PatchFinder.h"

typedef enum {
    ARM64_XREF_TYPE_B = 0,
    ARM64_XREF_TYPE_BL = 1,
    ARM64_XREF_TYPE_ADR = 2,
    ARM64_XREF_TYPE_ADRP_ADD = 3,
    ARM64_XREF_TYPE_ADRP_LDR = 4,
    ARM64_XREF_TYPE_ADRP_STR = 5,
} Arm64XrefType;

typedef enum {
    ARM64_XREF_TYPE_MASK_B  = (1 << ARM64_XREF_TYPE_B),
    ARM64_XREF_TYPE_MASK_BL = (1 << ARM64_XREF_TYPE_BL),
    ARM64_XREF_TYPE_MASK_CALL = (ARM64_XREF_TYPE_MASK_B | ARM64_XREF_TYPE_MASK_BL),

    ARM64_XREF_TYPE_MASK_ADR = (1 << ARM64_XREF_TYPE_ADR),
    ARM64_XREF_TYPE_MASK_ADRP_ADD = (1 << ARM64_XREF_TYPE_ADRP_ADD),
    ARM64_XREF_TYPE_MASK_ADRP_LDR = (1 << ARM64_XREF_TYPE_ADRP_LDR),
    ARM64_XREF_TYPE_MASK_ADRP_STR = (1 << ARM64_XREF_TYPE_ADRP_STR),
    ARM64_XREF_TYPE_MASK_REFERENCE = (ARM64_XREF_TYPE_MASK_ADR | ARM64_XREF_TYPE_MASK_ADRP_ADD | ARM64_XREF_TYPE_MASK_ADRP_LDR | ARM64_XREF_TYPE_MASK_ADRP_STR),

    ARM64_XREF_TYPE_ALL = (ARM64_XREF_TYPE_MASK_CALL | ARM64_XREF_TYPE_MASK_REFERENCE),
} Arm64XrefTypeMask;

uint64_t pfsec_arm64_resolve_adrp_ldr_str_add_reference(PFSection *section, uint64_t adrpAddr, uint64_t ldrStrAddAddr);
uint64_t pfsec_arm64_resolve_adrp_ldr_str_add_reference_auto(PFSection *section, uint64_t ldrStrAddAddr);
uint64_t pfsec_arm64_resolve_stub(PFSection *section, uint64_t stubAddr);
void pfsec_arm64_enumerate_xrefs(PFSection *section, Arm64XrefTypeMask types, void (^xrefBlock)(Arm64XrefType type, uint64_t source, uint64_t target, bool *stop));
#endif