#ifndef _BS_VM_BUILTINS_TYPE_H_
#define _BS_VM_BUILTINS_TYPE_H_

#include <ctype.h>

#include "../common.h"
#include "../vm.h"

RValue builtin_real(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_typeof(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_is_string(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_is_real(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_is_nan(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_is_infinity(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_is_bool(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_is_array(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_is_struct(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_is_int32(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_is_int64(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_is_undefined(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);

#if IS_WAD17_OR_HIGHER_ENABLED
RValue builtin_is_method(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_is_callable(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
#endif

#endif