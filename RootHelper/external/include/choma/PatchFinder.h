#include <stdint.h>
#include "MachO.h"

#define METRIC_TYPE_PATTERN 1
#define METRIC_TYPE_STRING_XREF 2
#define METRIC_TYPE_FUNCTION_XREF 3

typedef struct PFSection {
	uint64_t fileoff;
	uint64_t vmaddr;
	uint64_t size;
	uint8_t *cache;
	bool ownsCache;
} PFSection;

PFSection *macho_patchfinder_create_section(MachO *macho, const char *filesetEntryId, const char *segName, const char *sectName);
int macho_patchfinder_cache_section(PFSection *section, MachO *fromMacho);
void macho_patchfinder_section_free(PFSection *section);

typedef struct MetricShared {
	uint32_t type;
	PFSection *section;
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

BytePatternMetric *macho_patchfinder_create_byte_pattern_metric(PFSection *section, void *bytes, void *mask, size_t nbytes, BytePatternAlignment alignment);

void macho_patchfinder_run_metric(MachO *macho, void *metric, void (^matchBlock)(uint64_t vmaddr, bool *stop));
