#include "vm_random.h"

RValue builtin_random(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (1 > argCount) return RValue_makeReal(0.0);
    GMLReal n = RValue_toReal(args[0]);
    return RValue_makeReal(((GMLReal) rand() / (GMLReal) RAND_MAX) * n);
}

RValue builtin_random_range(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (2 > argCount) return RValue_makeReal(0.0);
    GMLReal lo = RValue_toReal(args[0]);
    GMLReal hi = RValue_toReal(args[1]);
    return RValue_makeReal(lo + ((GMLReal) rand() / (GMLReal) RAND_MAX) * (hi - lo));
}

RValue builtin_irandom(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (1 > argCount) return RValue_makeReal(0.0);
    int32_t n = RValue_toInt32(args[0]);
    if (0 >= n) return RValue_makeReal(0.0);
    return RValue_makeReal((GMLReal) (rand() % (n + 1)));
}

RValue builtin_irandom_range(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (2 > argCount) return RValue_makeReal(0.0);
    int32_t lo = RValue_toInt32(args[0]);
    int32_t hi = RValue_toInt32(args[1]);
    if (lo > hi) { int32_t tmp = lo; lo = hi; hi = tmp; }
    int32_t range = hi - lo + 1;
    if (0 >= range) return RValue_makeReal((GMLReal) lo);
    return RValue_makeReal((GMLReal) (lo + rand() % range));
}

RValue builtin_choose(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (1 > argCount) return RValue_makeUndefined();
    int32_t idx = rand() % argCount;
    // Steal ownership: the caller's RValue_free of args[idx] becomes a no-op, and the returned value owns the ref instead.
    RValue val = args[idx];
    if (val.type == RVALUE_STRING && val.string != nullptr && !val.ownsReference) {
        return RValue_makeOwnedString(safeStrdup(val.string));
    }
    args[idx].ownsReference = false;
    return val;
}

RValue builtin_randomize(VMContext* ctx, MAYBE_UNUSED RValue* args, MAYBE_UNUSED int32_t argCount) {
    if (ctx->hasFixedSeed) return RValue_makeUndefined();
    srand((unsigned int) time(nullptr) + (ctx->runner->frameCount * 2654435761u)); // 2654435761u = Knuth's multiplier
    return RValue_makeUndefined();
}