#include "vm_matrix.h"

RValue builtin_matrix_build_identity(MAYBE_UNUSED VMContext *ctx, MAYBE_UNUSED RValue *args, MAYBE_UNUSED int32_t argCount) {
    Matrix4f id;
    return RValue_makeArray(matrixToGml(ctx->dataWin->gen8.wadVersion, Matrix4f_identity(&id)));
}

RValue builtin_matrix_inverse(MAYBE_UNUSED VMContext *ctx, RValue *args, int32_t argCount) {
    if (argCount < 1 || argCount > 2) return RValue_makeUndefined();
    if (!rvalueIsMatrix(args[0])) return RValue_makeUndefined();

    bool toPrevMatrix = argCount == 2;
    GMLArray *destArray = toPrevMatrix ? args[1].array : nullptr;
    if (toPrevMatrix && !rvalueIsMatrix(args[1])) return RValue_makeUndefined();

    Matrix4f source, inverse;
    matrixFromGml(&source, args[0].array);
    if (!Matrix4f_inverse(&inverse, &source)) {
        return RValue_makeUndefined();
    } else if (!toPrevMatrix) {
        return RValue_makeArray(matrixToGml(ctx->dataWin->gen8.wadVersion, &inverse));
    } else {
        repeat (16, i) {
            *GMLArray_slot(destArray, i) = RValue_makeReal(inverse.m[i]);
        }
        return RValue_makeArrayWeak(destArray);
    }
}

RValue builtin_matrix_multiply(MAYBE_UNUSED VMContext *ctx, RValue *args, int32_t argCount) {
    if (argCount < 2 || argCount > 3) return RValue_makeUndefined();
    if (!rvalueIsMatrix(args[0]) || !rvalueIsMatrix(args[1])) return RValue_makeUndefined();

    bool toPrevMatrix = argCount == 3;
    GMLArray *destArray = toPrevMatrix ? args[2].array : nullptr;
    if (toPrevMatrix && !rvalueIsMatrix(args[2])) return RValue_makeUndefined();

    Matrix4f a, b, r;
    matrixFromGml(&a, args[0].array);
    matrixFromGml(&b, args[1].array);
    Matrix4f_multiply(&r, &a, &b);

    if (!toPrevMatrix) {
        return RValue_makeArray(matrixToGml(ctx->dataWin->gen8.wadVersion, &r));
    } else {
        repeat (16, i) {
            *GMLArray_slot(destArray, i) = RValue_makeReal(r.m[i]);
        }
        return RValue_makeArrayWeak(destArray);
    }
}

RValue builtin_matrix_build_lookat(MAYBE_UNUSED VMContext *ctx, RValue *args, int32_t argCount) {
    if (argCount < 9 || argCount > 10) return RValue_makeUndefined();

    GMLReal xFrom = RValue_toReal(args[0]);
    GMLReal yFrom = RValue_toReal(args[1]);
    GMLReal zFrom = RValue_toReal(args[2]);

    GMLReal xTo = RValue_toReal(args[3]);
    GMLReal yTo = RValue_toReal(args[4]);
    GMLReal zTo = RValue_toReal(args[5]);

    GMLReal xUp = RValue_toReal(args[6]);
    GMLReal yUp = RValue_toReal(args[7]);
    GMLReal zUp = RValue_toReal(args[8]);

    Matrix4f matrix;
    Matrix4f_identity(&matrix);

    Matrix4f_LookAt(&matrix, xFrom, yFrom, zFrom, xTo, yTo, zTo, xUp, yUp, zUp);

    bool toPrevMatrix = argCount == 10;
    GMLArray *destArray = toPrevMatrix ? args[9].array : nullptr;
    if (toPrevMatrix && !rvalueIsMatrix(args[9])) return RValue_makeUndefined();

    if (toPrevMatrix) {
        repeat (16, i) {
            *GMLArray_slot(destArray, i) = RValue_makeReal(matrix.m[i]);
        }
        return RValue_makeArrayWeak(destArray);
    } else {
        return RValue_makeArray(matrixToGml(ctx->dataWin->gen8.wadVersion, &matrix));
    }
}

RValue builtin_matrix_build_projection_ortho(MAYBE_UNUSED VMContext *ctx, RValue *args, int32_t argCount) {
    if (argCount < 4 || argCount > 5) return RValue_makeUndefined();
    GMLReal width = RValue_toReal(args[0]);
    GMLReal height = RValue_toReal(args[1]);
    GMLReal znear = RValue_toReal(args[2]);
    GMLReal zfar = RValue_toReal(args[3]);

    bool toPrevMatrix = argCount == 5;
    GMLArray *destArray = toPrevMatrix ? args[4].array : nullptr;
    if (toPrevMatrix && !rvalueIsMatrix(args[4])) return RValue_makeUndefined();

    Matrix4f mat;
    Matrix4f_Orthographic(&mat, width, height, zfar, znear);

    if (!toPrevMatrix) {
        return RValue_makeArray(matrixToGml(ctx->dataWin->gen8.wadVersion, &mat));
    } else {
        repeat (16, i) {
            *GMLArray_slot(destArray, i) = RValue_makeReal(mat.m[i]);
        }
        return RValue_makeArrayWeak(destArray);
    }
}

RValue builtin_matrix_build_projection_perspective_fov(MAYBE_UNUSED VMContext *ctx, RValue *args, int32_t argCount) {
    if (argCount < 4 || argCount > 5) return RValue_makeUndefined();
    GMLReal fov = RValue_toReal(args[0]) * (M_PI / 180.0);
    GMLReal aspect = RValue_toReal(args[1]);
    GMLReal znear = RValue_toReal(args[2]);
    GMLReal zfar = RValue_toReal(args[3]);

    bool toPrevMatrix = argCount == 5;
    GMLArray *destArray = toPrevMatrix ? args[4].array : nullptr;
    if (toPrevMatrix && !rvalueIsMatrix(args[4])) return RValue_makeUndefined();

    GMLReal scaleY = 1. / GMLReal_tan(fov / 2.);
    GMLReal scaleX = scaleY / aspect;

    Matrix4f mat;
    memset(mat.m, 0, sizeof(mat.m));

    mat.m[Matrix_getIndex(0, 0)] = scaleX;
    mat.m[Matrix_getIndex(1, 1)] = scaleY;
    mat.m[Matrix_getIndex(2, 2)] = zfar / (zfar - znear);
    mat.m[Matrix_getIndex(2, 3)] = -(zfar * znear) / (zfar - znear);
    mat.m[Matrix_getIndex(3, 2)] = 1.;

    if (!toPrevMatrix) {
        return RValue_makeArray(matrixToGml(ctx->dataWin->gen8.wadVersion, &mat));
    } else {
        repeat (16, i) {
            *GMLArray_slot(destArray, i) = RValue_makeReal(mat.m[i]);
        }
        return RValue_makeArrayWeak(destArray);
    }
}
RValue builtin_matrix_get(MAYBE_UNUSED VMContext *ctx, RValue *args, int32_t argCount) {
    int32_t Matrix = RValue_toInt32(args[0]);
    if (Matrix < 0 || Matrix > 2) return RValue_makeUndefined();
    bool toPrevMatrix = argCount == 2;
    GMLArray *destArray = toPrevMatrix ? args[1].array : nullptr;
    if (toPrevMatrix && !rvalueIsMatrix(args[1])) return RValue_makeUndefined();

    if (!toPrevMatrix) {
        return RValue_makeArray(matrixToGml(ctx->dataWin->gen8.wadVersion, &ctx->runner->renderer->gmlMatrices[Matrix]));
    } else {
        repeat (16, i) {
            *GMLArray_slot(destArray, i) = RValue_makeReal(ctx->runner->renderer->gmlMatrices[Matrix].m[i]);
        }
        return RValue_makeArrayWeak(destArray);
    }
}

RValue builtin_matrix_set(MAYBE_UNUSED VMContext *ctx, RValue *args, int32_t argCount) {
    int32_t Matrix = RValue_toInt32(args[0]);
    Matrix4f m;
    matrixFromGml(&m, args[1].array);
    if (Matrix < 0 || Matrix > 2) return RValue_makeUndefined();
    if (ctx->runner->renderer->vtable->setMatrix != nullptr) {
        ctx->runner->renderer->vtable->setMatrix(ctx->runner->renderer, Matrix, m);
    }

    return RValue_makeUndefined();
}