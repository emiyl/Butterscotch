#ifndef _BS_IOS_BRIDGE_H_
#define _BS_IOS_BRIDGE_H_

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Matches YoYoOperatingSystem values used by the runner.
typedef enum {
  BS_IOS_OS_UNKNOWN = -1,
  BS_IOS_OS_WINDOWS = 0,
  BS_IOS_OS_MACOSX = 1,
  BS_IOS_OS_PSP = 2,
  BS_IOS_OS_IOS = 3,
  BS_IOS_OS_ANDROID = 4,
} ButterscotchIOSOsType;

typedef enum {
  BS_IOS_CONTINUE = 0,
  BS_IOS_SHOULD_EXIT = 1,
  BS_IOS_CONTINUE_NO_PRESENT = 2,
} ButterscotchIOSFrameResult;

typedef void (*ButterscotchIOSWindowTitleCallback)(const char *title);

void ButterscotchIOS_setWindowTitleCallback(
    ButterscotchIOSWindowTitleCallback callback);
void ButterscotchIOS_setHostFramebuffer(uint32_t framebuffer);

bool ButterscotchIOS_startRunner(const char *dataWinPath, const char *savesPath,
                                 int32_t reportedOsType,
                                 uint32_t hostFramebuffer);
void ButterscotchIOS_stopRunner(void);

void ButterscotchIOS_beginFrame(void);
int32_t ButterscotchIOS_stepAndDraw(int32_t windowWidth, int32_t windowHeight,
                                    float deltaSeconds);

void ButterscotchIOS_onKeyDown(int32_t keyCode);
void ButterscotchIOS_onKeyUp(int32_t keyCode);
void ButterscotchIOS_onCharacter(uint32_t codePoint);

void ButterscotchIOS_setNormalizedCursorPosition(float x, float y);
void ButterscotchIOS_setMouseButtonState(int32_t button, bool down);

void ButterscotchIOS_setWidescreenHackAspectRatio(float aspectRatio);
void ButterscotchIOS_setFreeCamera(float panX, float panY, float zoom);

void ButterscotchIOS_suspendAudio(void);
void ButterscotchIOS_resumeAudio(void);

bool ButterscotchIOS_videoOpen(const char *absolutePath);
void ButterscotchIOS_videoClose(void);
bool ButterscotchIOS_videoIsOpen(void);
bool ButterscotchIOS_videoIsPlaying(void);
void ButterscotchIOS_videoPause(void);
void ButterscotchIOS_videoResume(void);
void ButterscotchIOS_videoEnableLoop(bool enabled);
void ButterscotchIOS_videoSetVolume(float volume);
int32_t ButterscotchIOS_videoGetFormat(void);

int32_t ButterscotchIOS_getTargetFrameHz(void);
int32_t ButterscotchIOS_getRoomCount(void);
const char *ButterscotchIOS_getRoomName(int32_t roomIndex);
void ButterscotchIOS_gotoRoom(int32_t roomIndex);
void ButterscotchIOS_getViewport(int32_t out[4]);
uint64_t ButterscotchIOS_getFrameCount(void);

#ifdef __cplusplus
}
#endif

#endif /* _BS_IOS_BRIDGE_H_ */
