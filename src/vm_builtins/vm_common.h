#ifndef _BS_VM_BUILTINS_COMMON_H_
#define _BS_VM_BUILTINS_COMMON_H_

#include <ctype.h>

#include "../common.h"
#include "../vm.h"
#include "../runner.h"
#include "../collision.h"

// Math
bool placeEmptyAt(Runner* runner, Instance* caller, GMLReal testX, GMLReal testY);
bool placeFreeAt(Runner* runner, Instance* caller, GMLReal testX, GMLReal testY);
bool bounceTestFree(Runner* runner, Instance* inst, GMLReal testX, GMLReal testY, bool useall);
void moveContactCommon(Runner* runner, Instance* inst, GMLReal dir, GMLReal maxdist, bool useall);
void moveOutsideCommon(Runner* runner, Instance* inst, GMLReal dir, GMLReal maxdist, bool useall);
void moveBounceCommon(Runner* runner, Instance* inst, bool advanced, bool useall);

// Matrix
bool rvalueIsMatrix(RValue rv);
bool matrixFromGml(Matrix4f *mat, GMLArray *arr);
GMLArray *matrixToGml(int32_t wadVersion, const Matrix4f *mat);

#endif