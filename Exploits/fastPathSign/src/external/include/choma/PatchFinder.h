#ifndef PATCHFINDER_H
#define PATCHFINDER_H

#include <stdint.h>
#include "MachO.h"

enum {
	PF_METRIC_TYPE_PATTERN,
	PF_METRIC_TYPE_STRING,
	PF_METRIC_TYPE_XREF,
};

typedef struct s_PFSection {
	MachO *macho;
	uint64_t fileoff;
	uint64_t vmaddr;
	uint64_t size;
	uint8_t *cache;
	bool ownsCache;
} PFSection;

PFSection *pfsec_init_from_macho(MachO *macho, const char *filesetEntryId, const char *segName, const char *sectName);
int pfsec_read_reloff(PFSection *section, uint64_t rel, size_t size, void *outBuf);
uint32_t pfsec_read32_reloff(PFSection *section, uint64_t rel);
int pfsec_read_at_address(PFSection *section, uint64_t vmaddr, void *outBuf, size_t size);
uint32_t pfsec_read32(PFSection *section, uint64_t vmaddr);
uint64_t pfsec_read64(PFSection *section, uint64_t vmaddr);
int pfsec_read_string(PFSection *section, uint64_t vmaddr, char **outString);
int pfsec_set_cached(PFSection *section, bool cached);
uint64_t pfsec_find_prev_inst(PFSection *section, uint64_t startAddr, uint32_t searchCount, uint32_t inst, uint32_t mask);
uint64_t pfsec_find_next_inst(PFSection *section, uint64_t startAddr, uint32_t searchCount, uint32_t inst, uint32_t mask);
uint64_t pfsec_find_function_start(PFSection *section, uint64_t midAddr);
void pfsec_free(PFSection *section);


typedef struct s_MetricShared {
	uint32_t type;
} MetricShared;

typedef struct s_PFPatternMetric {
	MetricShared shared;

	void *bytes;
	void *mask;
	size_t nbytes;
	uint16_t alignment;
} PFPatternMetric;

typedef struct s_PFStringMetric {
	MetricShared shared;

	char *string;
} PFStringMetric;

typedef enum {
    XREF_TYPE_MASK_CALL  = (1 << 0),
    XREF_TYPE_MASK_REFERENCE = (1 << 1),
    XREF_TYPE_MASK_ALL = (XREF_TYPE_MASK_CALL | XREF_TYPE_MASK_REFERENCE),
} PFXrefTypeMask;

typedef struct s_PFXrefMetric {
	MetricShared shared;

	uint64_t address;
	PFXrefTypeMask typeMask;
} PFXrefMetric;

PFPatternMetric *pfmetric_pattern_init(void *bytes, void *mask, size_t nbytes, uint16_t alignment);
PFStringMetric *pfmetric_string_init(const char *string);
PFXrefMetric *pfmetric_xref_init(uint64_t address, PFXrefTypeMask types);
void pfmetric_free(void *metric);

void pfmetric_run_in_range(PFSection *section, uint64_t startAddr, uint64_t endAddr, void *metric, void (^matchBlock)(uint64_t vmaddr, bool *stop));
void pfmetric_run(PFSection *section, void *metric, void (^matchBlock)(uint64_t vmaddr, bool *stop));
#endif