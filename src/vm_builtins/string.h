#ifndef _BS_VM_BUILTINS_STRING_H_ 
#define _BS_VM_BUILTINS_STRING_H_

#include <ctype.h>

#include "../common.h"
#include "../vm.h"
#include "../text_utils.h"

RValue builtin_string_length(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_string_letters(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_string_digits(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_string_lettersdigits(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_string_byte_length(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_string(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_string_upper(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_string_lower(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_string_copy(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_string_pos(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_string_char_at(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_string_ord_at(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_string_split(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_string_delete(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_string_insert(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_string_replace(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_string_replace_all(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_string_repeat(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_string_format(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_string_count(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_string_starts_with(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_ord(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_chr(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);

#endif