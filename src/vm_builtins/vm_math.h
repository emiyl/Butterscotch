#ifndef _BS_VM_BUILTINS_MATH_H_
#define _BS_VM_BUILTINS_MATH_H_

#include <ctype.h>

#include "../common.h"
#include "../vm.h"
#include "../rvalue.h"
#include "vm_common.h"

RValue builtin_floor(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_ceil(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_round(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_abs(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_frac(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_sign(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_max(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_min(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_mean(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_median(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_power(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_sqrt(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_log2(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_sqr(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_sin(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_arccos(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_arcsin(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_arctan(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_cos(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_dsin(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_dcos(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_darctan(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_darctan2(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_degtorad(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_radtodeg(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_clamp(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_lerp(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_tan(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_dot_product(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_point_distance(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_point_in_rectangle(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_point_in_circle(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_point_direction(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_angle_difference(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_distance_to_point(VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_distance_to_object(VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_move_towards_point(VMContext* ctx, RValue* args, MAYBE_UNUSED int32_t argCount);
RValue builtin_move_snap(VMContext* ctx, RValue* args, MAYBE_UNUSED int32_t argCount);
RValue builtin_move_wrap(VMContext* ctx, RValue* args, MAYBE_UNUSED int32_t argCount);
RValue builtin_move_contact_solid(VMContext* ctx, RValue* args, MAYBE_UNUSED int32_t argCount);
RValue builtin_move_outside_solid(VMContext* ctx, RValue* args, MAYBE_UNUSED int32_t argCount);
RValue builtin_move_outside_all(VMContext* ctx, RValue* args, MAYBE_UNUSED int32_t argCount);
RValue builtin_move_bounce_solid(VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_move_bounce_all(VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_lengthdir_x(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);
RValue builtin_lengthdir_y(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount);

#endif