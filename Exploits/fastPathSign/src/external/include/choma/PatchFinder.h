#include <stdint.h>
#include "MachO.h"

#define METRIC_TYPE_PATTERN 1
#define METRIC_TYPE_STRING_XREF 2
#define METRIC_TYPE_FUNCTION_XREF 3

typedef struct PFSection {
	MachO *macho;
	uint64_t fileoff;
	uint64_t vmaddr;
	uint64_t size;
	uint8_t *cache;
	bool ownsCache;
} PFSection;

PFSection *pf_section_init_from_macho(MachO *macho, const char *filesetEntryId, const char *segName, const char *sectName);
int pf_section_read_at_relative_offset(PFSection *section, uint64_t rel, size_t size, void *outBuf);
int pf_section_read_at_address(PFSection *section, uint64_t vmaddr, void *outBuf, size_t size);
uint32_t pf_section_read32(PFSection *section, uint64_t vmaddr);
int pf_section_set_cached(PFSection *section, bool cached);
void pf_section_free(PFSection *section);


typedef struct MetricShared {
	uint32_t type;
} MetricShared;


typedef enum {
	BYTE_PATTERN_ALIGN_8_BIT,
	BYTE_PATTERN_ALIGN_16_BIT,
	BYTE_PATTERN_ALIGN_32_BIT,
	BYTE_PATTERN_ALIGN_64_BIT,
} BytePatternAlignment;

typedef struct BytePatternMetric {
	MetricShared shared;

	void *bytes;
	void *mask;
	size_t nbytes;
	BytePatternAlignment alignment;
} BytePatternMetric;

BytePatternMetric *pf_create_byte_pattern_metric(void *bytes, void *mask, size_t nbytes, BytePatternAlignment alignment);
void pf_section_run_metric(PFSection *section, void *metric, void (^matchBlock)(uint64_t vmaddr, bool *stop));
