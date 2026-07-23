#include "vm_math.h"

RValue builtin_floor(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (1 > argCount) return RValue_makeReal(0.0);
    return RValue_makeReal(GMLReal_floor(RValue_toReal(args[0])));
}

RValue builtin_ceil(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (1 > argCount) return RValue_makeReal(0.0);
    return RValue_makeReal(GMLReal_ceil(RValue_toReal(args[0])));
}

RValue builtin_round(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (1 > argCount) return RValue_makeReal(0.0);
    return RValue_makeReal(GMLReal_bankersRound(RValue_toReal(args[0])));
}

RValue builtin_abs(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (1 > argCount) return RValue_makeReal(0.0);
    return RValue_makeReal(GMLReal_fabs(RValue_toReal(args[0])));
}

RValue builtin_frac(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (1 > argCount) return RValue_makeReal(0.0);
    GMLReal val = RValue_toReal(args[0]);
    GMLReal truncated = (val >= 0.0) ? GMLReal_floor(val) : GMLReal_ceil(val);
    return RValue_makeReal(val - truncated);
}

RValue builtin_sign(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (1 > argCount) return RValue_makeReal(0.0);
    GMLReal val = RValue_toReal(args[0]);
    GMLReal result = (val > 0.0) ? 1.0 : ((0.0 > val) ? -1.0 : 0.0);
    return RValue_makeReal(result);
}

RValue builtin_max(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (1 > argCount) return RValue_makeReal(0.0);
    GMLReal result = -INFINITY;
    repeat(argCount, i) {
        GMLReal val = RValue_toReal(args[i]);
        if (val > result) result = val;
    }
    return RValue_makeReal(result);
}

RValue builtin_min(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (1 > argCount) return RValue_makeReal(0.0);
    GMLReal result = INFINITY;
    repeat(argCount, i) {
        GMLReal val = RValue_toReal(args[i]);
        if (result > val) result = val;
    }
    return RValue_makeReal(result);
}

static int compareReals(const void* a, const void* b) {
    GMLReal lhs = *(const GMLReal*) a;
    GMLReal rhs = *(const GMLReal*) b;
    if (lhs > rhs) return 1;
    if (rhs > lhs) return -1;
    return 0;
}

RValue builtin_mean(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (1 > argCount) return RValue_makeReal(0.0);
    GMLReal result = 0.0;
    repeat(argCount, i) {
        result += RValue_toReal(args[i]);
    }
    return RValue_makeReal(result / argCount);
}

RValue builtin_median(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (1 > argCount) return RValue_makeReal(0.0);
    // GMS docs cap median at 16 args; 32-element stack buffer gives 2x margin, with malloc fallback for safety.
    GMLReal stackBuf[32];
    GMLReal* buf = stackBuf;
    if (argCount > 32) buf = (GMLReal*) malloc(sizeof(GMLReal) * argCount);
    repeat(argCount, i) buf[i] = RValue_toReal(args[i]);
    qsort(buf, argCount, sizeof(GMLReal), compareReals);
    // Match HTML5: when argCount is even, return the upper of the two middle values (arr[argCount/2], not arr[argCount/2 - 1]).
    GMLReal result = buf[argCount / 2];
    if (stackBuf != buf) free(buf);
    return RValue_makeReal(result);
}

RValue builtin_power(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (2 > argCount) return RValue_makeReal(0.0);
    return RValue_makeReal(GMLReal_pow(RValue_toReal(args[0]), RValue_toReal(args[1])));
}

RValue builtin_sqrt(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (1 > argCount) return RValue_makeReal(0.0);
    return RValue_makeReal(GMLReal_sqrt(RValue_toReal(args[0])));
}

RValue builtin_log2(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (1 > argCount) return RValue_makeReal(0.0);
    return RValue_makeReal(GMLReal_log2(RValue_toReal(args[0])));
}

RValue builtin_sqr(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (1 > argCount) return RValue_makeReal(0.0);
    GMLReal val = RValue_toReal(args[0]);
    return RValue_makeReal(val * val);
}

RValue builtin_sin(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (1 > argCount) return RValue_makeReal(0.0);
    return RValue_makeReal(GMLReal_sin(RValue_toReal(args[0])));
}

RValue builtin_arccos(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (1 > argCount) return RValue_makeReal(0.0);
    return RValue_makeReal(GMLReal_acos(RValue_toReal(args[0])));
}

RValue builtin_arcsin(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (1 > argCount) return RValue_makeReal(0.0);
    return RValue_makeReal(GMLReal_asin(RValue_toReal(args[0])));
}

RValue builtin_arctan(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (1 > argCount) return RValue_makeReal(0.0);
    GMLReal y = RValue_toReal(args[0]);
    return RValue_makeReal(GMLReal_atan(y));
}

RValue builtin_cos(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (1 > argCount) return RValue_makeReal(0.0);
    return RValue_makeReal(GMLReal_cos(RValue_toReal(args[0])));
}

RValue builtin_dsin(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (1 > argCount) return RValue_makeReal(0.0);
    return RValue_makeReal(GMLReal_sin(RValue_toReal(args[0]) * (M_PI / 180.0)));
}

RValue builtin_dcos(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (1 > argCount) return RValue_makeReal(0.0);
    return RValue_makeReal(GMLReal_cos(RValue_toReal(args[0]) * (M_PI / 180.0)));
}

RValue builtin_darctan(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (1 > argCount) return RValue_makeReal(0.0);
    GMLReal y = RValue_toReal(args[0]);
    return RValue_makeReal(GMLReal_atan(y) * (180.0 / M_PI));
}

RValue builtin_darctan2(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (2 > argCount) return RValue_makeReal(0.0);
    GMLReal y = RValue_toReal(args[0]);
    GMLReal x = RValue_toReal(args[1]);
    return RValue_makeReal(GMLReal_atan2(y, x) * (180.0 / M_PI));
}

RValue builtin_degtorad(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (1 > argCount) return RValue_makeReal(0.0);
    return RValue_makeReal(RValue_toReal(args[0]) * (M_PI / 180.0));
}

RValue builtin_radtodeg(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (1 > argCount) return RValue_makeReal(0.0);
    return RValue_makeReal(RValue_toReal(args[0]) * (180.0 / M_PI));
}

RValue builtin_clamp(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (3 > argCount) return RValue_makeReal(0.0);
    GMLReal val = RValue_toReal(args[0]);
    GMLReal lo = RValue_toReal(args[1]);
    GMLReal hi = RValue_toReal(args[2]);
    if (lo > val) val = lo;
    if (val > hi) val = hi;
    return RValue_makeReal(val);
}

RValue builtin_lerp(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (3 > argCount) return RValue_makeReal(0.0);
    GMLReal a = RValue_toReal(args[0]);
    GMLReal b = RValue_toReal(args[1]);
    GMLReal t = RValue_toReal(args[2]);
    GMLReal result = a + (b - a) * t;
#ifdef USE_FLOAT_REALS
    // When using floats, floating point inaccuracies can cause games to softlock, so if the lerp did not do any meaningful movement, we'll *nudge* it a bit forward.
    // This COULD have unforeseen consequences, but it also fixes some games (example: DELTARUNE Chapter 2's pre-giga queen cutscene)
    if (result == a && a != b) result = GMLReal_nextafter(a, b);
#endif
    return RValue_makeReal(result);
}

RValue builtin_tan(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (1 > argCount) return RValue_makeReal(0.0);
    return RValue_makeReal(GMLReal_tan(RValue_toReal(args[0])));
}

RValue builtin_dot_product(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (4 > argCount) return RValue_makeReal(0.0);
    GMLReal x1 = RValue_toReal(args[0]);
    GMLReal y1 = RValue_toReal(args[1]);
    GMLReal x2 = RValue_toReal(args[2]);
    GMLReal y2 = RValue_toReal(args[3]);
    return RValue_makeReal(x1 * x2 + y1 * y2);
}

RValue builtin_point_distance(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (4 > argCount) return RValue_makeReal(0.0);
    GMLReal dx = RValue_toReal(args[2]) - RValue_toReal(args[0]);
    GMLReal dy = RValue_toReal(args[3]) - RValue_toReal(args[1]);
    return RValue_makeReal(GMLReal_sqrt(dx * dx + dy * dy));
}

RValue builtin_point_in_rectangle(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (6 > argCount) return RValue_makeBool(false);
    GMLReal px = RValue_toReal(args[0]);
    GMLReal py = RValue_toReal(args[1]);
    GMLReal x1 = RValue_toReal(args[2]);
    GMLReal y1 = RValue_toReal(args[3]);
    GMLReal x2 = RValue_toReal(args[4]);
    GMLReal y2 = RValue_toReal(args[5]);
    return RValue_makeBool(px >= x1 && px <= x2 && py >= y1 && py <= y2);
}

RValue builtin_point_in_circle(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (5 > argCount) return RValue_makeBool(false);
    GMLReal px = RValue_toReal(args[0]);
    GMLReal py = RValue_toReal(args[1]);
    GMLReal cx = RValue_toReal(args[2]);
    GMLReal cy = RValue_toReal(args[3]);
    GMLReal rad = RValue_toReal(args[4]);
    GMLReal dx = px - cx;
    GMLReal dy = py - cy;
    return RValue_makeBool(dx * dx + dy * dy <= rad * rad);
}

// See GameMaker-HTML5's Function_Maths.js
RValue builtin_point_direction(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (4 > argCount) return RValue_makeReal(0.0);

    GMLReal x1 = RValue_toReal(args[0]);
    GMLReal y1 = RValue_toReal(args[1]);
    GMLReal x2 = RValue_toReal(args[2]);
    GMLReal y2 = RValue_toReal(args[3]);

    GMLReal x = x2 - x1;
    GMLReal y = y2 - y1;

    if (x == 0) {
        if (y > 0) return RValue_makeReal(270.0);
        else if (y < 0) return RValue_makeReal(90.0);
        else return RValue_makeReal(0.0);
    } else {
        GMLReal dd = 180.0 * GMLReal_atan2(y, x) / M_PI;
        dd = GMLReal_bankersRound(dd * 1000000.0) / 1000000.0;
        if (dd <= 0.0) {
            return RValue_makeReal(-dd);
        } else {
            return RValue_makeReal(360.0 - dd);
        }
    }
}

RValue builtin_angle_difference(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (2 > argCount) return RValue_makeReal(0.0);
    GMLReal src = RValue_toReal(args[0]);
    GMLReal dest = RValue_toReal(args[1]);
    return RValue_makeReal(GMLReal_fmod(GMLReal_fmod(src - dest, 360.0) + 540.0, 360.0) - 180.0);
}

RValue builtin_distance_to_point(VMContext* ctx, RValue* args, int32_t argCount) {
    if (2 > argCount) return RValue_makeReal(0.0);
    GMLReal px = RValue_toReal(args[0]);
    GMLReal py = RValue_toReal(args[1]);

    Instance* inst = ctx->currentInstance;
    InstanceBBox bbox = Collision_computeBBox(ctx->runner, inst);
    GMLReal bboxLeft, bboxRight, bboxTop, bboxBottom;
    if (!bbox.valid) {
        // No sprite/mask: treat bbox as a single point at (x, y)
        bboxLeft = bboxRight = inst->x;
        bboxTop = bboxBottom = inst->y;
    } else {
        bboxLeft = bbox.left;
        bboxRight = bbox.right;
        bboxTop = bbox.top;
        bboxBottom = bbox.bottom;
    }

    // Distance from point to nearest edge of bbox (0 if inside)
    GMLReal xd = 0.0;
    GMLReal yd = 0.0;
    if (px > bboxRight)  xd = px - bboxRight;
    if (px < bboxLeft)   xd = px - bboxLeft;
    if (py > bboxBottom) yd = py - bboxBottom;
    if (py < bboxTop)    yd = py - bboxTop;

    return RValue_makeReal(GMLReal_sqrt(xd * xd + yd * yd));
}

// distance_to_object(obj)
// Returns the minimum bbox-to-bbox distance between the calling instance and the nearest instance of the given object.
RValue builtin_distance_to_object(VMContext* ctx, RValue* args, int32_t argCount) {
    if (1 > argCount) return RValue_makeReal(0.0);

    Runner* runner = ctx->runner;
    int32_t targetObjIndex = VM_resolveInstanceTarget(ctx, RValue_toInt32(args[0]));
    Instance* self = ctx->currentInstance;

    // Compute self bbox
    Sprite* selfSpr = Collision_getSprite(ctx->dataWin, self);
    if (selfSpr == nullptr) return RValue_makeReal(0.0);
    InstanceBBox selfBBox = Collision_computeBBox(ctx->runner, self);
    if (!selfBBox.valid) return RValue_makeReal(0.0);

    GMLReal minDistSq = 1e20;

    int32_t snapBase = Runner_pushInstancesForTarget(runner, targetObjIndex);
    int32_t snapEnd  = (int32_t) arrlen(runner->instanceSnapshots);
    for (int32_t i = snapBase; snapEnd > i; i++) {
        Instance* inst = runner->instanceSnapshots[i];
        if (!inst->active || inst == self) continue;

        InstanceBBox otherBBox = Collision_computeBBox(ctx->runner, inst);
        if (!otherBBox.valid) continue;

        GMLReal xd = 0.0;
        GMLReal yd = 0.0;
        if (otherBBox.left > selfBBox.right)  xd = otherBBox.left - selfBBox.right;
        if (selfBBox.left > otherBBox.right)  xd = selfBBox.left - otherBBox.right;
        if (otherBBox.top > selfBBox.bottom)  yd = otherBBox.top - selfBBox.bottom;
        if (selfBBox.top > otherBBox.bottom)  yd = selfBBox.top - otherBBox.bottom;

        GMLReal distSq = xd * xd + yd * yd;
        if (minDistSq > distSq) minDistSq = distSq;
    }
    Runner_popInstanceSnapshot(runner, snapBase);

    return RValue_makeReal(GMLReal_sqrt(minDistSq));
}

RValue builtin_move_towards_point(VMContext* ctx, RValue* args, MAYBE_UNUSED int32_t argCount) {
    GMLReal targetX = RValue_toReal(args[0]);
    GMLReal targetY = RValue_toReal(args[1]);
    GMLReal spd = RValue_toReal(args[2]);
    Instance* inst = ctx->currentInstance;
    GMLReal dx = targetX - inst->x;
    GMLReal dy = targetY - inst->y;
    GMLReal dir = GMLReal_atan2(-dy, dx) * (180.0 / M_PI);
    if (dir < 0.0) dir += 360.0;
    inst->direction = (float) dir;
    inst->speed = (float) spd;
    Instance_computeComponentsFromSpeed(inst);
    return RValue_makeReal(0.0);
}

RValue builtin_move_snap(VMContext* ctx, RValue* args, MAYBE_UNUSED int32_t argCount) {
    GMLReal hsnap = RValue_toReal(args[0]);
    GMLReal vsnap = RValue_toReal(args[1]);
    Instance* inst = ctx->currentInstance;
    if (hsnap > 0.0) {
        inst->x = (float) (GMLReal_floor((inst->x / hsnap) + 0.5) * hsnap);
        SpatialGrid_markInstanceAsDirty(ctx->runner->spatialGrid, inst);
    }
    if (vsnap > 0.0) {
        inst->y = (float) (GMLReal_floor((inst->y / vsnap) + 0.5) * vsnap);
        SpatialGrid_markInstanceAsDirty(ctx->runner->spatialGrid, inst);
    }
    return RValue_makeReal(0.0);
}

RValue builtin_move_wrap(VMContext* ctx, RValue* args, MAYBE_UNUSED int32_t argCount) {
    bool hor = RValue_toBool(args[0]);
    bool vert = RValue_toBool(args[1]);
    GMLReal margin = RValue_toReal(args[2]);
    Instance* inst = ctx->currentInstance;
    if (hor) {
        if (inst->x < -margin) {
            inst->x = (float)(inst->x + ctx->runner->currentRoom->width + 2 * margin);
            SpatialGrid_markInstanceAsDirty(ctx->runner->spatialGrid, inst);
        }
        if (inst->x > ctx->runner->currentRoom->width + margin) {
            inst->x = (float)(inst->x - ctx->runner->currentRoom->width - 2 * margin);
            SpatialGrid_markInstanceAsDirty(ctx->runner->spatialGrid, inst);
        }
    }
    if (vert) {
        if (inst->y < -margin) {
            inst->y = (float)(inst->y + ctx->runner->currentRoom->height + 2 * margin);
            SpatialGrid_markInstanceAsDirty(ctx->runner->spatialGrid, inst);
        }
        if (inst->y > ctx->runner->currentRoom->height + margin) {
            inst->y = (float)(inst->y - ctx->runner->currentRoom->height - 2 * margin);
            SpatialGrid_markInstanceAsDirty(ctx->runner->spatialGrid, inst);
        }
    }
    return RValue_makeReal(0.0);
}

RValue builtin_move_contact_solid(VMContext* ctx, RValue* args, MAYBE_UNUSED int32_t argCount) {
    if (ctx->currentInstance == nullptr) return RValue_makeUndefined();
    GMLReal dir = RValue_toReal(args[0]);
    GMLReal maxdist = RValue_toReal(args[1]);
    moveContactCommon(ctx->runner, ctx->currentInstance, dir, maxdist, false);
    return RValue_makeUndefined();
}

RValue builtin_move_outside_solid(VMContext* ctx, RValue* args, MAYBE_UNUSED int32_t argCount) {
    if (ctx->currentInstance == nullptr) return RValue_makeUndefined();
    GMLReal dir = RValue_toReal(args[0]);
    GMLReal maxdist = RValue_toReal(args[1]);
    moveOutsideCommon(ctx->runner, ctx->currentInstance, dir, maxdist, false);
    return RValue_makeUndefined();
}

RValue builtin_move_outside_all(VMContext* ctx, RValue* args, MAYBE_UNUSED int32_t argCount) {
    if (ctx->currentInstance == nullptr) return RValue_makeUndefined();
    GMLReal dir = RValue_toReal(args[0]);
    GMLReal maxdist = RValue_toReal(args[1]);
    moveOutsideCommon(ctx->runner, ctx->currentInstance, dir, maxdist, true);
    return RValue_makeUndefined();
}

RValue builtin_move_bounce_solid(VMContext* ctx, RValue* args, int32_t argCount) {
    if (1 > argCount || ctx->currentInstance == nullptr) return RValue_makeUndefined();
    bool advanced = RValue_toBool(args[0]);
    moveBounceCommon(ctx->runner, ctx->currentInstance, advanced, false);
    return RValue_makeUndefined();
}

RValue builtin_move_bounce_all(VMContext* ctx, RValue* args, int32_t argCount) {
    if (1 > argCount || ctx->currentInstance == nullptr) return RValue_makeUndefined();
    bool advanced = RValue_toBool(args[0]);
    moveBounceCommon(ctx->runner, ctx->currentInstance, advanced, true);
    return RValue_makeUndefined();
}

// For lengthdir: Anything that's 1e-4 > abs(result) should be coerced to 0 to avoid precision drift.
// If not, precision drift can cause a LOT of issues, especially on platforms that use floats instead of doubles.
RValue builtin_lengthdir_x(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (2 > argCount) return RValue_makeReal(0.0);
    GMLReal len = RValue_toReal(args[0]);
    GMLReal dir = RValue_toReal(args[1]) * (M_PI / 180.0);
    GMLReal result = len * GMLReal_cos(dir);
    if ((GMLReal) 1e-4 > GMLReal_fabs(result)) result = 0.0;
    return RValue_makeReal(result);
}

RValue builtin_lengthdir_y(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (2 > argCount) return RValue_makeReal(0.0);
    GMLReal len = RValue_toReal(args[0]);
    GMLReal dir = RValue_toReal(args[1]) * (M_PI / 180.0);
    GMLReal result = -len * GMLReal_sin(dir);
    if ((GMLReal) 1e-4 > GMLReal_fabs(result)) result = 0.0;
    return RValue_makeReal(result);
}