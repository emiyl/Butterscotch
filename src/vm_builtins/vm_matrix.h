#ifndef _BS_VM_BUILTINS_MATRIX_H_
#define _BS_VM_BUILTINS_MATRIX_H_

#include <ctype.h>

#include "../common.h"
#include "../vm.h"
#include "vm_common.h"

RValue builtin_matrix_build_identity(MAYBE_UNUSED VMContext *ctx, MAYBE_UNUSED RValue *args, MAYBE_UNUSED int32_t argCount);
RValue builtin_matrix_inverse(MAYBE_UNUSED VMContext *ctx, RValue *args, int32_t argCount);
RValue builtin_matrix_multiply(MAYBE_UNUSED VMContext *ctx, RValue *args, int32_t argCount);
RValue builtin_matrix_build_lookat(MAYBE_UNUSED VMContext *ctx, RValue *args, int32_t argCount);
RValue builtin_matrix_build_projection_ortho(MAYBE_UNUSED VMContext *ctx, RValue *args, int32_t argCount);
RValue builtin_matrix_build_projection_perspective_fov(MAYBE_UNUSED VMContext *ctx, RValue *args, int32_t argCount);
RValue builtin_matrix_get(MAYBE_UNUSED VMContext *ctx, RValue *args, int32_t argCount);
RValue builtin_matrix_set(MAYBE_UNUSED VMContext *ctx, RValue *args, int32_t argCount);

#endif