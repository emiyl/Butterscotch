#include "butterscotch_ios.h"

#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>

#include <OpenGLES/ES3/gl.h>
#include <OpenGLES/ES3/glext.h>

#include "common.h"
#include "data_win.h"
#include "runner.h"
#include "overlay_file_system.h"
#ifdef USE_MINIAUDIO
#include "ma_audio_system.h"
#endif
#include "noop_audio_system.h"
#include "gl/gl_renderer.h"
#include "runner_keyboard.h"
#include "stb_ds.h"
#include "utils.h"

static Runner* gRunner = nullptr;

static char* gCurrentDataWinPath = nullptr;
static char* gSavesPath = nullptr;
static YoYoOperatingSystem gReportedOs = OS_IOS;
static GLuint gHostFramebuffer = 0;

static float gWidescreenHackAspectRatio = 0.0f;
static float gFreeCamPanX = 0.0f;
static float gFreeCamPanY = 0.0f;
static float gFreeCamZoom = 1.0f;
static float gNormalizedCursorX = 0.0f;
static float gNormalizedCursorY = 0.0f;

static int32_t gWindowW = 0;
static int32_t gWindowH = 0;

static ButterscotchIOSWindowTitleCallback gTitleCallback = nullptr;

static bool iosGetWindowSize(int32_t* outW, int32_t* outH) {
    if (gWindowW <= 0 || gWindowH <= 0) return false;
    if (outW != nullptr) *outW = gWindowW;
    if (outH != nullptr) *outH = gWindowH;
    return true;
}

static void iosSetWindowTitle(const char* title) {
    if (gTitleCallback == nullptr) return;
    gTitleCallback(title == nullptr ? "" : title);
}

static char** extractRunnerArguments(char* rawArguments) {
    char* saveptr;
    char* copy = safeStrdup(rawArguments);
    char* token = strtok_r(copy, " \t\r\n", &saveptr);
    char** array = nullptr;

    while (token != nullptr) {
        arrput(array, safeStrdup(token));
        token = strtok_r(nullptr, " \t\r\n", &saveptr);
    }

    free(copy);
    return array;
}

static DataWinParserOptions createParserOptions(void) {
    DataWinParserOptions options = {0};
    options.parseGen8 = true;
    options.parseOptn = true;
    options.parseLang = true;
    options.parseExtn = true;
    options.parseSond = true;
    options.parseAgrp = true;
    options.parseSprt = true;
    options.parseBgnd = true;
    options.parsePath = true;
    options.parseScpt = true;
    options.parseGlob = true;
    options.parseShdr = true;
    options.parseFont = true;
    options.parseTmln = true;
    options.parseObjt = true;
    options.parseRoom = true;
    options.parseTpag = true;
    options.parseCode = true;
    options.parseVari = true;
    options.parseFunc = true;
    options.parseStrg = true;
    options.parseTxtr = true;
    options.parseAudo = true;
    options.skipLoadingPreciseMasksForNonPreciseSprites = true;
    options.loadType = DATAWINLOADTYPE_LOAD_IN_MEMORY_AHEAD_OF_TIME;
    options.lazyLoadRooms = false;
    options.eagerlyLoadedRooms = nullptr;
    return options;
}

static void teardownRunner(void) {
    Runner* runner = gRunner;
    if (runner == nullptr) return;
    gRunner = nullptr;

    runner->audioSystem->vtable->destroy(runner->audioSystem);
    runner->audioSystem = nullptr;
    runner->renderer->vtable->destroy(runner->renderer);

    DataWin* dataWin = runner->dataWin;
    VMContext* vm = runner->vmContext;
    Runner_free(runner);
    VM_free(vm);
    DataWin_free(dataWin);
}

static bool startRunnerFromPath(const char* dataWinPath, const char* savesPath, char** gameArgs, YoYoOperatingSystem osType) {
    requireNotNull(dataWinPath);
    requireNotNull(savesPath);
    requireNotNull(gameArgs);

    if (gRunner != nullptr) return false;

    if (mkdir(savesPath, 0777) != 0 && errno != EEXIST) {
        fprintf(stderr, "Could not create saves dir %s: %s\n", savesPath, strerror(errno));
    }

    DataWin* dataWin = DataWin_parse(dataWinPath, createParserOptions());
    if (dataWin == nullptr) {
        fprintf(stderr, "Failed to parse data.win at %s\n", dataWinPath);
        return false;
    }

    char* bundleDir = nullptr;
    const char* lastSlash = strrchr(dataWinPath, '/');
    if (lastSlash != nullptr) {
        size_t len = (size_t) (lastSlash - dataWinPath + 1);
        bundleDir = safeMalloc(len + 1);
        memcpy(bundleDir, dataWinPath, len);
        bundleDir[len] = '\0';
    } else {
        bundleDir = safeStrdup("./");
    }

    VMContext* vm = VM_create(dataWin);
    Renderer* renderer = GLRenderer_create();
    ((GLRenderer*) renderer)->hostFramebuffer = gHostFramebuffer;
    ((GLRenderer*) renderer)->isGLES = true;
    OverlayFileSystem* overlayFs = OverlayFileSystem_create(bundleDir, savesPath);
    free(bundleDir);

    AudioSystem* audioSystem = nullptr;
#ifdef USE_MINIAUDIO
    audioSystem = (AudioSystem*) MaAudioSystem_create(dataWin);
    if (audioSystem == nullptr) {
        fprintf(stderr, "MaAudioSystem_create returned NULL; falling back to silent audio\n");
    }
#endif
    if (audioSystem == nullptr) {
        audioSystem = (AudioSystem*) NoopAudioSystem_create();
    }

    Runner* runner = Runner_create(dataWin, vm, renderer, (FileSystem*) overlayFs, audioSystem);
    runner->osType = osType;
    runner->setWindowTitle = iosSetWindowTitle;
    runner->windowHasFocus = nullptr;
    runner->getWindowSize = iosGetWindowSize;
    Runner_setGameArgs(runner, gameArgs, (int32_t) arrlen(gameArgs));

    const char* initialTitle = dataWin->gen8.displayName;
    if (initialTitle == nullptr || initialTitle[0] == '\0') initialTitle = dataWin->gen8.name;
    iosSetWindowTitle(initialTitle);

    Runner_initFirstRoom(runner);

    char* newDataWinPath = safeStrdup(dataWinPath);
    char* newSavesPath = safeStrdup(savesPath);
    free(gCurrentDataWinPath);
    free(gSavesPath);
    gCurrentDataWinPath = newDataWinPath;
    gSavesPath = newSavesPath;
    gReportedOs = osType;

    gRunner = runner;
    return true;
}

static bool performGameChange(const char* workingDirectory, char* launchParameters) {
    char** newArguments = extractRunnerArguments(launchParameters);

    char* dataWinFilename = nullptr;
    size_t argCount = arrlen(newArguments);
    repeat(argCount, i) {
        if (strcmp(newArguments[i], "-game") == 0 && argCount - 1 > i) {
            dataWinFilename = newArguments[i + 1];
            break;
        }
    }

    if (dataWinFilename == nullptr) {
        fprintf(stderr, "Runner: Launch parameters '%s' did not contain a '-game <file>' entry! Shutting down...\n", launchParameters);
        repeat(arrlen(newArguments), i) free(newArguments[i]);
        arrfree(newArguments);
        return false;
    }

    char* parentDir = safeStrdup(gCurrentDataWinPath);
    {
        char* lastSlash = strrchr(parentDir, '/');
        char* lastBackslash = strrchr(parentDir, '\\');
        char* sep = (lastSlash > lastBackslash) ? lastSlash : lastBackslash;
        if (sep != nullptr) {
            *sep = '\0';
        } else {
            parentDir[0] = '.';
            parentDir[1] = '\0';
        }
    }

    size_t newPathLen = strlen(parentDir) + strlen(workingDirectory) + 1 + strlen(dataWinFilename) + 1;
    char* newPath = safeMalloc(newPathLen);
    snprintf(newPath, newPathLen, "%s%s/%s", parentDir, workingDirectory, dataWinFilename);
    free(parentDir);

    char** gameArgs = nullptr;
    arrput(gameArgs, safeStrdup("butterscotch"));
    repeat(arrlen(newArguments), i) arrput(gameArgs, safeStrdup(newArguments[i]));

    teardownRunner();
    bool ok = startRunnerFromPath(newPath, gSavesPath, gameArgs, gReportedOs);

    free(newPath);
    repeat(arrlen(gameArgs), i) free(gameArgs[i]);
    arrfree(gameArgs);
    repeat(arrlen(newArguments), i) free(newArguments[i]);
    arrfree(newArguments);

    return ok;
}

void ButterscotchIOS_setWindowTitleCallback(ButterscotchIOSWindowTitleCallback callback) {
    gTitleCallback = callback;
}

void ButterscotchIOS_setHostFramebuffer(uint32_t framebuffer) {
    gHostFramebuffer = (GLuint) framebuffer;
    if (gRunner != nullptr) {
        ((GLRenderer*) gRunner->renderer)->hostFramebuffer = gHostFramebuffer;
    }
}

bool ButterscotchIOS_startRunner(const char* dataWinPath, const char* savesPath, int32_t reportedOsType, uint32_t hostFramebuffer) {
    if (gRunner != nullptr) return false;
    gHostFramebuffer = (GLuint) hostFramebuffer;

    char** gameArgs = nullptr;
    arrput(gameArgs, safeStrdup("butterscotch"));

    bool ok = startRunnerFromPath(dataWinPath, savesPath, gameArgs, (YoYoOperatingSystem) reportedOsType);

    gWidescreenHackAspectRatio = 0.0f;
    gFreeCamPanX = 0.0f;
    gFreeCamPanY = 0.0f;
    gFreeCamZoom = 1.0f;

    repeat(arrlen(gameArgs), i) free(gameArgs[i]);
    arrfree(gameArgs);

    return ok;
}

void ButterscotchIOS_stopRunner(void) {
    teardownRunner();
    free(gCurrentDataWinPath);
    gCurrentDataWinPath = nullptr;
    free(gSavesPath);
    gSavesPath = nullptr;
}

void ButterscotchIOS_beginFrame(void) {
    Runner* runner = gRunner;
    if (runner == nullptr) return;

    RunnerKeyboard_beginFrame(runner->keyboard);

    RunnerGamepadState* gamepads = runner->gamepads;
    if (gamepads != nullptr) {
        for (int i = 0; i < MAX_GAMEPADS; i++) {
            GamepadSlot* slot = &gamepads->slots[i];
            slot->connectedPrev = slot->connected;
            memset(slot->buttonPressed, 0, sizeof(slot->buttonPressed));
            memset(slot->buttonReleased, 0, sizeof(slot->buttonReleased));
        }
    }

    RunnerMouse_beginFrame(runner->mouse);
}

void ButterscotchIOS_onKeyDown(int32_t keyCode) {
    Runner* runner = gRunner;
    if (runner == nullptr) return;
    if (keyCode < 0 || keyCode >= GML_KEY_COUNT) return;
    RunnerKeyboard_onKeyDown(runner->keyboard, keyCode);
}

void ButterscotchIOS_onKeyUp(int32_t keyCode) {
    Runner* runner = gRunner;
    if (runner == nullptr) return;
    if (keyCode < 0 || keyCode >= GML_KEY_COUNT) return;
    RunnerKeyboard_onKeyUp(runner->keyboard, keyCode);
}

void ButterscotchIOS_onCharacter(uint32_t codePoint) {
    Runner* runner = gRunner;
    if (runner == nullptr) return;
    if (codePoint == 0) return;
    RunnerKeyboard_onCharacter(runner->keyboard, codePoint);
}

void ButterscotchIOS_setNormalizedCursorPosition(float x, float y) {
    gNormalizedCursorX = x;
    gNormalizedCursorY = y;
}

void ButterscotchIOS_setMouseButtonState(int32_t button, bool down) {
    Runner* runner = gRunner;
    if (runner == nullptr) return;

    if (down) {
        RunnerMouse_onButtonDown(runner->mouse, button);
    } else {
        RunnerMouse_onButtonUp(runner->mouse, button);
    }
}

void ButterscotchIOS_setWidescreenHackAspectRatio(float aspectRatio) {
    gWidescreenHackAspectRatio = aspectRatio;
}

void ButterscotchIOS_setFreeCamera(float panX, float panY, float zoom) {
    gFreeCamPanX = panX;
    gFreeCamPanY = panY;
    gFreeCamZoom = zoom;
}

int32_t ButterscotchIOS_stepAndDraw(int32_t windowWidth, int32_t windowHeight, float deltaSeconds) {
    Runner* runner = gRunner;
    if (runner == nullptr) return BS_IOS_SHOULD_EXIT;

    if (0.0f > deltaSeconds) deltaSeconds = 0.0f;
    runner->deltaTime = deltaSeconds * 1000000.0;

    if (runner->shouldExit) return BS_IOS_SHOULD_EXIT;

    if (runner->pendingWorkingDirectory != nullptr && runner->pendingLaunchParameters != nullptr) {
        char* nextWorkingDirectory = runner->pendingWorkingDirectory;
        char* nextLaunchParameters = runner->pendingLaunchParameters;
        runner->pendingWorkingDirectory = nullptr;
        runner->pendingLaunchParameters = nullptr;

        bool ok = performGameChange(nextWorkingDirectory, nextLaunchParameters);
        free(nextWorkingDirectory);
        free(nextLaunchParameters);
        return ok ? BS_IOS_CONTINUE : BS_IOS_SHOULD_EXIT;
    }

    Runner_step(runner);

    runner->freeCamPanX = gFreeCamPanX;
    runner->freeCamPanY = gFreeCamPanY;
    runner->freeCamZoom = (gFreeCamZoom > 0.0f) ? gFreeCamZoom : 1.0f;

    if (deltaSeconds > 0.1f) deltaSeconds = 0.1f;
    runner->audioSystem->vtable->update(runner->audioSystem, deltaSeconds);

    if (windowWidth < 1) windowWidth = 1;
    if (windowHeight < 1) windowHeight = 1;

    gWindowW = windowWidth;
    gWindowH = windowHeight;

    Gen8* gen8 = &runner->dataWin->gen8;

    if (!runner->appSurfaceEnabled) {
        runner->applicationWidth = windowWidth;
        runner->applicationHeight = windowHeight;
        runner->usingAppSurface = false;
    } else {
        if (runner->applicationWidth <= 0 || runner->applicationHeight <= 0) {
            runner->applicationWidth = (int32_t) gen8->defaultWindowWidth;
            runner->applicationHeight = (int32_t) gen8->defaultWindowHeight;
        }
        runner->usingAppSurface = true;
    }

    int32_t gameW = runner->applicationWidth;
    int32_t gameH = runner->applicationHeight;

    runner->widescreenExtraWidth = 0;
    runner->widescreenExtraHeight = 0;

    if (gWidescreenHackAspectRatio > 0.0f && runner->usingAppSurface && gameW > 0 && gameH > 0) {
        float nativeAspect = (float) gameW / (float) gameH;
        if (gWidescreenHackAspectRatio > nativeAspect) {
            int32_t targetW = (int32_t) ((float) gameH * gWidescreenHackAspectRatio + 0.5f);
            if (targetW > gameW) {
                runner->widescreenExtraWidth = targetW - gameW;
                gameW = targetW;
            }
        } else if (gWidescreenHackAspectRatio < nativeAspect) {
            int32_t targetH = (int32_t) ((float) gameW / gWidescreenHackAspectRatio + 0.5f);
            if (targetH > gameH) {
                runner->widescreenExtraHeight = targetH - gameH;
                gameH = targetH;
            }
        }
    }

    glBindFramebuffer(GL_FRAMEBUFFER, gHostFramebuffer);
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);

    Runner_drawPre(runner, windowWidth, windowHeight);

    Runner_beginFrame(runner, gameW, gameH, windowWidth, windowHeight, windowWidth, windowHeight);
    Runner_updateMousePosition(runner, windowWidth, windowHeight, gNormalizedCursorX * windowWidth, gNormalizedCursorY * windowHeight);

    Runner_drawViews(runner, gameW, gameH, false);
    runner->renderer->vtable->endFrameInit(runner->renderer);
    Runner_drawPost(runner, windowWidth, windowHeight);
    runner->renderer->vtable->endFrameEnd(runner->renderer);
    Runner_drawGUI(runner, windowWidth, windowHeight, gameW, gameH);

    bool shouldPresent = (runner->pendingRoom == -1);
    Runner_handlePendingRoomChange(runner);

    return shouldPresent ? BS_IOS_CONTINUE : BS_IOS_CONTINUE_NO_PRESENT;
}

void ButterscotchIOS_suspendAudio(void) {
    if (gRunner == nullptr || gRunner->audioSystem == nullptr) return;
    gRunner->audioSystem->vtable->suspend(gRunner->audioSystem);
}

void ButterscotchIOS_resumeAudio(void) {
    if (gRunner == nullptr || gRunner->audioSystem == nullptr) return;
    gRunner->audioSystem->vtable->resume(gRunner->audioSystem);
}

int32_t ButterscotchIOS_getTargetFrameHz(void) {
    Runner* runner = gRunner;
    if (runner == nullptr || runner->currentRoom == nullptr) return 0;
    return (int32_t) runner->currentRoom->speed;
}

int32_t ButterscotchIOS_getRoomCount(void) {
    Runner* runner = gRunner;
    if (runner == nullptr || runner->currentRoom == nullptr) return 0;
    return (int32_t) runner->dataWin->room.count;
}

const char* ButterscotchIOS_getRoomName(int32_t roomIndex) {
    Runner* runner = gRunner;
    if (runner == nullptr || runner->currentRoom == nullptr) return nullptr;
    if (roomIndex < 0 || roomIndex >= (int32_t) runner->dataWin->room.count) return nullptr;
    return runner->dataWin->room.rooms[roomIndex].name;
}

void ButterscotchIOS_gotoRoom(int32_t roomIndex) {
    Runner* runner = gRunner;
    if (runner == nullptr || runner->currentRoom == nullptr) return;
    runner->pendingRoom = roomIndex;
}

void ButterscotchIOS_getViewport(int32_t out[4]) {
    if (out == nullptr) return;
    Runner* runner = gRunner;
    if (runner == nullptr) {
        out[0] = 0;
        out[1] = 0;
        out[2] = 0;
        out[3] = 0;
        return;
    }
    out[0] = runner->viewportX;
    out[1] = runner->viewportY;
    out[2] = runner->viewportW;
    out[3] = runner->viewportH;
}

uint64_t ButterscotchIOS_getFrameCount(void) {
    if (gRunner == nullptr) return 0;
    return (uint64_t) gRunner->frameCount;
}
