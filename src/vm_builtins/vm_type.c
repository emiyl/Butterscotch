#include "vm_type.h"

RValue builtin_real(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (1 > argCount) return RValue_makeReal(0.0);
    return RValue_makeReal(RValue_toReal(args[0]));
}

RValue builtin_typeof(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (1 > argCount) return RValue_makeUndefined();

    RValue arg = args[0];

    switch (arg.type) {
        // TODO: RVALUE_POINTER, RVALUE_NULL
        case RVALUE_REAL: return RValue_makeString("number");
        case RVALUE_STRING: return RValue_makeString("string");
        case RVALUE_ARRAY: return RValue_makeString("array");
        case RVALUE_BOOL: return RValue_makeString("bool");
        case RVALUE_INT32: return RValue_makeString("int32");
        case RVALUE_INT64: return RValue_makeString("int64");
        case RVALUE_UNDEFINED: return RValue_makeString("undefined");
        case RVALUE_METHOD: return RValue_makeString("method");
        case RVALUE_STRUCT: return RValue_makeString("struct");
        case RVALUE_ASSETREF: return RValue_makeString("ref");
        default: return RValue_makeString("default");
    }
}

RValue builtin_is_string(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (1 > argCount) return RValue_makeBool(false);
    return RValue_makeBool(args[0].type == RVALUE_STRING);
}

RValue builtin_is_real(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (1 > argCount) return RValue_makeBool(false);
    bool result = args[0].type == RVALUE_REAL || args[0].type == RVALUE_INT32 || args[0].type == RVALUE_INT64 || args[0].type == RVALUE_BOOL;
    return RValue_makeBool(result);
}

RValue builtin_is_nan(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (1 > argCount) return RValue_makeBool(false);
    return RValue_makeBool(args[0].type == RVALUE_REAL && isnan(RValue_toReal(args[0])));
}

RValue builtin_is_infinity(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (1 > argCount) return RValue_makeBool(false);
    return RValue_makeBool(args[0].type == RVALUE_REAL && isinf(RValue_toReal(args[0])));
}

RValue builtin_is_bool(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (1 > argCount) return RValue_makeBool(false);
    return RValue_makeBool(args[0].type == RVALUE_BOOL);
}

RValue builtin_is_array(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (1 > argCount) return RValue_makeBool(false);
    return RValue_makeBool(args[0].type == RVALUE_ARRAY);
}

RValue builtin_is_struct(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (1 > argCount) return RValue_makeBool(false);
    return RValue_makeBool(args[0].type == RVALUE_STRUCT);
}

RValue builtin_is_int32(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (1 > argCount) return RValue_makeBool(false);
    return RValue_makeBool(args[0].type == RVALUE_INT32);
}

RValue builtin_is_int64(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (1 > argCount) return RValue_makeBool(false);
    return RValue_makeBool(args[0].type == RVALUE_INT64);
}

RValue builtin_is_undefined(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (1 > argCount) return RValue_makeBool(true);
    return RValue_makeBool(args[0].type == RVALUE_UNDEFINED);
}

#if IS_WAD17_OR_HIGHER_ENABLED
RValue builtin_is_method(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (1 > argCount) return RValue_makeBool(false);
    return RValue_makeBool(args[0].type == RVALUE_METHOD);
}

RValue builtin_is_callable(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (1 > argCount) return RValue_makeBool(false);
    RValue v = args[0];

    if (v.type == RVALUE_METHOD) return RValue_makeBool(v.method != nullptr);
    if (v.type == RVALUE_ASSETREF) return RValue_makeBool(v.assetRefType == ASSET_TYPE_SCRIPT);

    if (v.type == RVALUE_REAL || v.type == RVALUE_INT32 || v.type == RVALUE_INT64) {
        int32_t idx = RValue_toInt32(v);
        if (0 > idx) return RValue_makeBool(false);

        // BC17+: scriptName compiles to a FUNC-table index. Resolve via codeIndexByName or builtinMap.
        if (ctx->dataWin->func.functionCount > (uint32_t) idx) {
            const char* funcName = ctx->dataWin->func.functions[idx].name;
            if (funcName != nullptr) {
                if (shgeti(ctx->codeIndexByName, (char*) funcName) >= 0) return RValue_makeBool(true);
                if (shgeti(ctx->builtinMap, (char*) funcName) >= 0) return RValue_makeBool(true);
            }
        }

        // Fallback: SCPT index
        if (ctx->dataWin->scpt.count > (uint32_t) idx) {
            int32_t codeId = ctx->dataWin->scpt.scripts[idx].codeId;
            if (codeId >= 0 && ctx->dataWin->code.count > (uint32_t) codeId) return RValue_makeBool(true);
        }
        return RValue_makeBool(false);
    }

    return RValue_makeBool(false);
}
#endif