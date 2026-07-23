#include "vm_common.h"

// place_empty(x, y) - returns true if no instance overlaps at position (x, y), checking ALL instances (not just solid)
bool placeEmptyAt(Runner* runner, Instance* caller, GMLReal testX, GMLReal testY) {
    GMLReal savedX = caller->x;
    GMLReal savedY = caller->y;
    caller->x = testX;
    caller->y = testY;

    InstanceBBox callerBBox = Collision_computeBBox(runner, caller);
    bool empty = true;

    if (callerBBox.valid) {
        int32_t instanceCount = (int32_t) arrlen(runner->instances);
        repeat(instanceCount, i) {
            Instance* other = runner->instances[i];
            if (!other->active || other == caller) continue;

            InstanceBBox otherBBox = Collision_computeBBox(runner, other);
            if (!otherBBox.valid) continue;

            if (Collision_instancesOverlapPrecise(runner, caller, other, callerBBox, otherBBox)) {
                empty = false;
                break;
            }
        }
    }

    caller->x = savedX;
    caller->y = savedY;
    return empty;
}

// placeFreeAt - returns true if no SOLID instance overlaps at position (x, y)
bool placeFreeAt(Runner* runner, Instance* caller, GMLReal testX, GMLReal testY) {
    GMLReal savedX = caller->x;
    GMLReal savedY = caller->y;
    caller->x = testX;
    caller->y = testY;

    InstanceBBox callerBBox = Collision_computeBBox(runner, caller);
    bool free = true;

    if (callerBBox.valid) {
        int32_t instanceCount = (int32_t) arrlen(runner->instances);
        repeat(instanceCount, i) {
            Instance* other = runner->instances[i];
            if (!other->active || !other->solid || other == caller) continue;

            InstanceBBox otherBBox = Collision_computeBBox(runner, other);
            if (!otherBBox.valid) continue;

            if (Collision_instancesOverlapPrecise(runner, caller, other, callerBBox, otherBBox)) {
                free = false;
                break;
            }
        }
    }

    caller->x = savedX;
    caller->y = savedY;
    return free;
}

// Tests whether the current instance can occupy (testX, testY) without colliding (useall=true checks all instances, false checks only solids).
bool bounceTestFree(Runner* runner, Instance* inst, GMLReal testX, GMLReal testY, bool useall) {
    if (useall) {
        return placeEmptyAt(runner, inst, testX, testY);
    }
    return placeFreeAt(runner, inst, testX, testY);
}

// Steps the current instance up to maxdist pixels in "dir" (degrees), stopping the unit before it would collide. useall=true tests all instances, false tests only solids.
void moveContactCommon(Runner* runner, Instance* inst, GMLReal dir, GMLReal maxdist, bool useall) {
    int32_t steps = (maxdist <= 0.0) ? 1000 : (int32_t) GMLReal_bankersRound(maxdist);
    GMLReal rad = dir * (M_PI / 180.0);
    GMLReal dx = GMLReal_cos(rad);
    GMLReal dy = -GMLReal_sin(rad);
    if (!bounceTestFree(runner, inst, inst->x, inst->y, useall)) {
        return;
    }
    for (int32_t i = 1; steps >= i; i++) {
        GMLReal nx = inst->x + dx;
        GMLReal ny = inst->y + dy;
        if (!bounceTestFree(runner, inst, nx, ny, useall)) {
            return;
        }
        inst->x = (float) nx;
        inst->y = (float) ny;
        SpatialGrid_markInstanceAsDirty(runner->spatialGrid, inst);
    }
}

// Moves the current instance up to maxdist pixels in "dir" (degrees) until it is no longer colliding (lands in a free spot). The inverse of moveContactCommon: if the current position is already free the instance is not moved. useall=true tests all instances, false tests only solids.
void moveOutsideCommon(Runner* runner, Instance* inst, GMLReal dir, GMLReal maxdist, bool useall) {
    int32_t steps = (maxdist <= 0.0) ? 1000 : (int32_t) GMLReal_bankersRound(maxdist);
    GMLReal rad = dir * (M_PI / 180.0);
    GMLReal dx = GMLReal_cos(rad);
    GMLReal dy = -GMLReal_sin(rad);
    if (bounceTestFree(runner, inst, inst->x, inst->y, useall)) {
        return;
    }
    for (int32_t i = 1; steps >= i; i++) {
        inst->x = (float) (inst->x + dx);
        inst->y = (float) (inst->y + dy);
        SpatialGrid_markInstanceAsDirty(runner->spatialGrid, inst);
        if (bounceTestFree(runner, inst, inst->x, inst->y, useall)) {
            return;
        }
    }
}

void moveBounceCommon(Runner* runner, Instance* inst, bool advanced, bool useall) {
    bool didBounce = false;
    if (!bounceTestFree(runner, inst, inst->x, inst->y, useall)) {
        inst->x = inst->xprevious;
        inst->y = inst->yprevious;
        SpatialGrid_markInstanceAsDirty(runner->spatialGrid, inst);
        didBounce = true;
    }

    GMLReal xx = inst->x;
    GMLReal yy = inst->y;

    if (advanced) {
        int32_t n = 18;
        GMLReal dir = 10.0 * GMLReal_round(inst->direction / 10.0);
        GMLReal ldir = dir;
        GMLReal rdir = dir;
        for (int32_t i = 1; 2 * n > i; i++) {
            ldir -= 180.0 / (GMLReal) n;
            GMLReal xn = xx + inst->speed * GMLReal_cos(ldir * (M_PI / 180.0));
            GMLReal yn = yy - inst->speed * GMLReal_sin(ldir * (M_PI / 180.0));
            if (bounceTestFree(runner, inst, xn, yn, useall)) {
                break;
            }
            didBounce = true;
        }
        for (int32_t i = 1; 2 * n > i; i++) {
            rdir += 180.0 / (GMLReal) n;
            GMLReal xn = xx + inst->speed * GMLReal_cos(rdir * (M_PI / 180.0));
            GMLReal yn = yy - inst->speed * GMLReal_sin(rdir * (M_PI / 180.0));
            if (bounceTestFree(runner, inst, xn, yn, useall)) {
                break;
            }
            didBounce = true;
        }
        if (didBounce) {
            inst->direction = (float) (180.0 + (ldir + rdir) - dir);
            Instance_computeComponentsFromSpeed(inst);
        }
    } else {
        bool canMoveH = bounceTestFree(runner, inst, inst->x + inst->hspeed, inst->y, useall);
        bool canMoveV = bounceTestFree(runner, inst, inst->x, inst->y + inst->vspeed, useall);
        bool canMoveDiagonally = bounceTestFree(runner, inst, inst->x + inst->hspeed, inst->y + inst->vspeed, useall);
        if (!canMoveH && !canMoveV) {
            inst->hspeed = -inst->hspeed;
            inst->vspeed = -inst->vspeed;
        } else if (canMoveH && canMoveV && !canMoveDiagonally) {
            inst->hspeed = -inst->hspeed;
            inst->vspeed = -inst->vspeed;
        } else if (!canMoveH) {
            inst->hspeed = -inst->hspeed;
        } else if (!canMoveV) {
            inst->vspeed = -inst->vspeed;
        }
        Instance_computeSpeedFromComponents(inst);
    }
}