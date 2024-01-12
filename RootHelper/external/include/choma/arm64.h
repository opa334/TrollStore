#ifndef ARM64_H
#define ARM64_H

#include "Util.h"

typedef enum {
	// registers
	ARM64_REG_TYPE_X,
	ARM64_REG_TYPE_W,

	// vector shit
	ARM64_REG_TYPE_Q,
	ARM64_REG_TYPE_D,
	ARM64_REG_TYPE_S,
	ARM64_REG_TYPE_H,
	ARM64_REG_TYPE_B,
} arm64_register_type;

enum {
	ARM64_REG_MASK_ANY_FLAG = (1 << 0),
	ARM64_REG_MASK_X_W = (1 << 1),
	ARM64_REG_MASK_VECTOR = (1 << 2),
	ARM64_REG_MASK_ALL = (ARM64_REG_MASK_X_W | ARM64_REG_MASK_VECTOR),

	ARM64_REG_MASK_ANY_X_W = (ARM64_REG_MASK_X_W | ARM64_REG_MASK_ANY_FLAG),
	ARM64_REG_MASK_ANY_VECTOR = (ARM64_REG_MASK_VECTOR | ARM64_REG_MASK_ANY_FLAG),
	ARM64_REG_MASK_ANY_ALL = (ARM64_REG_MASK_ALL | ARM64_REG_MASK_ANY_FLAG),
};

typedef enum {
	LDR_STR_TYPE_ANY, // NOTE: "ANY" will inevitably also match STUR and LDUR instructions
	LDR_STR_TYPE_POST_INDEX,
	LDR_STR_TYPE_PRE_INDEX,
	LDR_STR_TYPE_UNSIGNED,
} arm64_ldr_str_type;

typedef struct s_arm64_register {
	uint8_t mask;
	arm64_register_type type;
	uint8_t num;
} arm64_register;

#define ARM64_REG(type_, num_) (arm64_register){.mask = ARM64_REG_MASK_ALL, .type = type_, .num = num_}
#define ARM64_REG_X(x) ARM64_REG(ARM64_REG_TYPE_X, x)
#define ARM64_REG_W(x) ARM64_REG(ARM64_REG_TYPE_W, x)
#define ARM64_REG_Q(x) ARM64_REG(ARM64_REG_TYPE_Q, x)
#define ARM64_REG_S(x) ARM64_REG(ARM64_REG_TYPE_S, x)
#define ARM64_REG_H(x) ARM64_REG(ARM64_REG_TYPE_H, x)
#define ARM64_REG_B(x) ARM64_REG(ARM64_REG_TYPE_B, x)
#define ARM64_REG_ANY (arm64_register){.mask = ARM64_REG_MASK_ANY_ALL, .type = 0, .num = 0}
#define ARM64_REG_ANY_X_W (arm64_register){.mask = ARM64_REG_MASK_ANY_X_W, .type = 0, .num = 0}
#define ARM64_REG_ANY_VECTOR (arm64_register){.mask = ARM64_REG_MASK_ANY_VECTOR, .type = 0, .num = 0}
#define ARM64_REG_GET_TYPE(x) (x.type)
#define ARM64_REG_IS_X(x) (x.type == ARM64_REG_TYPE_X)
#define ARM64_REG_IS_W(x) (x.type == ARM64_REG_TYPE_W)
#define ARM64_REG_IS_VECTOR(x) (x.type == ARM64_REG_TYPE_Q || x.type == ARM64_REG_TYPE_D || x.type == ARM64_REG_TYPE_S || x.type == ARM64_REG_TYPE_H || x.type == ARM64_REG_TYPE_B)
#define ARM64_REG_GET_NUM(x) (x.num & 0x1f)
#define ARM64_REG_IS_ANY(x) (x.mask == ARM64_REG_MASK_ANY_ALL)
#define ARM64_REG_IS_ANY_X_W(x) (x.mask == ARM64_REG_MASK_ANY_X_W)
#define ARM64_REG_IS_ANY_VECTOR(x) (x.mask == ARM64_REG_MASK_ANY_VECTOR)
uint8_t arm64_reg_type_get_width(arm64_register_type type);
const char *arm64_reg_type_get_string(arm64_register_type type);
const char *arm64_reg_get_type_string(arm64_register reg);

#define ARM64_REG_NUM_SP 31

typedef struct s_arm64_cond {
	bool isSet;
	uint8_t value;
} arm64_cond;
#define ARM64_COND(x) (arm64_cond){.isSet = true, .value = x}
#define ARM64_COND_ANY (arm64_cond){.isSet = false, .value = 0}
#define ARM64_COND_GET_VAL(x) (x.value & 0xf)
#define ARM64_COND_IS_SET(x) x.isSet

int arm64_gen_b_l(optional_bool optIsBl, optional_uint64_t optOrigin, optional_uint64_t optTarget, uint32_t *bytesOut, uint32_t *maskOut);
int arm64_dec_b_l(uint32_t inst, uint64_t origin, uint64_t *targetOut, bool *isBlOut);
int arm64_gen_b_c_cond(optional_bool optIsBc, optional_uint64_t optOrigin, optional_uint64_t optTarget, arm64_cond optCond, uint32_t *bytesOut, uint32_t *maskOut);
int arm64_dec_b_c_cond(uint32_t inst, uint64_t origin, uint64_t *targetOut, arm64_cond *condOut, bool *isBcOut);
int arm64_gen_adr_p(optional_bool optIsAdrp, optional_uint64_t optOrigin, optional_uint64_t optTarget, arm64_register reg, uint32_t *bytesOut, uint32_t *maskOut);
int arm64_dec_adr_p(uint32_t inst, uint64_t origin, uint64_t *targetOut, arm64_register *registerOut, bool *isAdrpOut);
int arm64_gen_mov_imm(char type, arm64_register destinationReg, optional_uint64_t optImm, optional_uint64_t optShift, uint32_t *bytesOut, uint32_t *maskOut);
int arm64_dec_mov_imm(uint32_t inst, arm64_register *destinationRegOut, uint64_t *immOut, uint64_t *shiftOut, char *typeOut);
int arm64_gen_add_imm(arm64_register destinationReg, arm64_register sourceReg, optional_uint64_t optImm, uint32_t *bytesOut, uint32_t *maskOut);
int arm64_dec_add_imm(uint32_t inst, arm64_register *destinationRegOut, arm64_register *sourceRegOut, uint16_t *immOut);
int arm64_gen_ldr_imm(char type, arm64_ldr_str_type instType, arm64_register destinationReg, arm64_register addrReg, optional_uint64_t optImm, uint32_t *bytesOut, uint32_t *maskOut);
int arm64_dec_ldr_imm(uint32_t inst, arm64_register *destinationReg, arm64_register *addrReg, uint64_t *immOut, char *typeOut, arm64_ldr_str_type *instTypeOut);
int arm64_gen_str_imm(char type, arm64_ldr_str_type instType, arm64_register sourceReg, arm64_register addrReg, optional_uint64_t optImm, uint32_t *bytesOut, uint32_t *maskOut);
int arm64_dec_str_imm(uint32_t inst, arm64_register *sourceRegOut, arm64_register *addrRegOut, uint64_t *immOut, char *typeOut, arm64_ldr_str_type *instTypeOut);
int arm64_gen_ldr_lit(arm64_register destinationReg, optional_uint64_t optImm, uint32_t *bytesOut, uint32_t *maskOut);
int arm64_dec_ldr_lit(uint32_t inst, arm64_register *destinationReg, int64_t *immOut);
int arm64_gen_cb_n_z(optional_bool isCbnz, arm64_register reg, optional_uint64_t optTarget, uint32_t *bytesOut, uint32_t *maskOut);
int arm64_dec_cb_n_z(uint32_t inst, uint64_t origin, bool *isCbnzOut, arm64_register *regOut, uint64_t *targetOut);
#endif