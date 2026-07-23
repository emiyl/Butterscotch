#ifndef _BS_VM_BUILTINS_COMMON_H
#define _BS_VM_BUILTINS_COMMON_H

#include <ctype.h>

#include "../common.h"
#include "../vm.h"
#include "../rvalue.h"
#include "../runner.h"
#include "../collision.h"

bool placeEmptyAt(Runner* runner, Instance* caller, GMLReal testX, GMLReal testY);
bool placeFreeAt(Runner* runner, Instance* caller, GMLReal testX, GMLReal testY);
bool bounceTestFree(Runner* runner, Instance* inst, GMLReal testX, GMLReal testY, bool useall);
void moveContactCommon(Runner* runner, Instance* inst, GMLReal dir, GMLReal maxdist, bool useall);
void moveOutsideCommon(Runner* runner, Instance* inst, GMLReal dir, GMLReal maxdist, bool useall);
void moveBounceCommon(Runner* runner, Instance* inst, bool advanced, bool useall);

#endif