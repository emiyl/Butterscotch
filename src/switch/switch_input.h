#ifndef _BS_SWITCH_INPUT_H_
#define _BS_SWITCH_INPUT_H_

#include <stdbool.h>

struct Runner;

bool SwitchInput_handleEvents(struct Runner* runner);
bool SwitchInput_checkPausePressed(void);
bool SwitchInput_checkPauseHeld(void);

#endif
