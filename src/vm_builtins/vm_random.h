#ifndef _BS_VM_BUILTINS_RANDOM_H_
#define _BS_VM_BUILTINS_RANDOM_H_

#include <ctype.h>
#include <time.h>

#include "../common.h"
#include "../vm.h"
#include "vm_common.h"

RValue builtin_random(MAYBE_UNUSED VMContext *ctx, RValue *args, int32_t argCount);
RValue builtin_random_range(MAYBE_UNUSED VMContext *ctx, RValue *args, int32_t argCount);
RValue builtin_irandom(MAYBE_UNUSED VMContext *ctx, RValue *args, int32_t argCount);
RValue builtin_irandom_range(MAYBE_UNUSED VMContext *ctx, RValue *args, int32_t argCount);
RValue builtin_choose(MAYBE_UNUSED VMContext *ctx, RValue *args, int32_t argCount);
RValue builtin_randomize(VMContext *ctx, MAYBE_UNUSED RValue *args, MAYBE_UNUSED int32_t argCount);

#endif