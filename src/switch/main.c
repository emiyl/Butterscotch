#include <loop.h>
#include <switch.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <GLES3/gl3.h>

/* For SDL_main */
#if defined(USE_SDL1)
#include <SDL/SDL_main.h>
#elif defined(USE_SDL2)
#include <SDL2/SDL_main.h>
#elif defined(USE_SDL3)
#include <SDL3/SDL_main.h>
#endif

typedef enum DataWinLocation {
    DATAWIN_LOCATION_NONE,
    DATAWIN_LOCATION_SDMC,
    DATAWIN_LOCATION_ROMFS
} DataWinLocation;

void switchOpenLogFile(const char* logPath);
void switchCloseLogFile(void);

bool romFsInitSucceeded = false;
bool sdmcMountSucceeded = false;
static char dataWinPath[64];

static bool GetExecutableFolder(const char* argv0, char* folder, size_t folderSize) {
    if (argv0 == NULL || strncmp(argv0, "sdmc:", 5) != 0) return false;

    const char* lastSlash = strrchr(argv0, '/');
    if (lastSlash == NULL || lastSlash == argv0) return false;

    size_t length = (size_t)(lastSlash - argv0);
    if (length == 0 || length >= folderSize) return false;

    memcpy(folder, argv0, length);
    folder[length] = '\0';
    return true;
}

DataWinLocation GetDataWinLoadType(const char* executableFolder) {
    Result res;
    struct stat s;
    char logPath[1024];
    bool foundRomFsDataWin = false;

    printf("Initializing SDMC...\n");
    res = fsdevMountSdmc();
    if (R_SUCCEEDED(res)) {
        printf("SDMC initialized successfully.\n");
        sdmcMountSucceeded = true;
        if (executableFolder != NULL &&
            snprintf(logPath, sizeof(logPath), "%s/log.txt", executableFolder) < (int)sizeof(logPath)) {
            switchOpenLogFile(logPath);
        }
    } else {
        printf("Failed to initialize SDMC: 0x%x\n", res);
    }

    printf("Initializing RomFS...\n");
    res = romfsInit();
    if (R_SUCCEEDED(res)) {
        romFsInitSucceeded = true;
        printf("RomFS initialized successfully.\n");
        if (stat("romfs:/data.win", &s) == 0) {
            printf("Found data.win in RomFS.\n");
            foundRomFsDataWin = true;
        }
    } else {
        printf("Failed to initialize RomFS: 0x%x\n", res);
    }

    if (foundRomFsDataWin) {
        snprintf(dataWinPath, sizeof(dataWinPath), "romfs:/data.win");
        return DATAWIN_LOCATION_ROMFS;
    }
    if (sdmcMountSucceeded && executableFolder != NULL &&
        snprintf(dataWinPath, sizeof(dataWinPath), "%s/data.win", executableFolder) < (int)sizeof(dataWinPath) &&
        stat(dataWinPath, &s) == 0) {
        printf("Found data.win in SDMC.\n");
        return DATAWIN_LOCATION_SDMC;
    }
    if (sdmcMountSucceeded &&
        stat("sdmc:/switch/butterscotch/data.win", &s) == 0) {
        printf("Found fallback data.win in SDMC.\n");
        snprintf(dataWinPath, sizeof(dataWinPath),
            "sdmc:/switch/butterscotch/data.win");
        return DATAWIN_LOCATION_SDMC;
    }

    return DATAWIN_LOCATION_NONE;
}

int main(int argc, char* argv[]) {
    (void)argc;
    setbuf(stdout, NULL);
    setbuf(stderr, NULL);

    consoleInit(NULL);

    printf("Starting application...\n");

    char executableFolder[1024] = {0};
    const char* dataWinFolder = NULL;

    if (GetExecutableFolder(argv[0], executableFolder, sizeof(executableFolder))) {
        dataWinFolder = executableFolder;
    }

    DataWinLocation dataWinLocation = GetDataWinLoadType(dataWinFolder);

    CommandLineArgs args = {0};

    args.exitAtFrame = -1;
#ifdef ENABLE_VM_TRACING
    args.traceBytecodeAfterFrame = 0;
#endif
    args.speedMultiplier = 1.0;
    args.fastForwardSpeed = 0.0;
    args.osType = OS_WINDOWS;
    args.profilerFramesBetween = 0;
    args.loadType = DATAWINLOADTYPE_LOAD_IN_MEMORY_AHEAD_OF_TIME;
#if defined(ENABLE_MODERN_GL)
    args.renderer = MODERN_GL;
#else
    args.renderer = SOFTWARE;
#endif
    switch (dataWinLocation) {
        case DATAWIN_LOCATION_SDMC:
        case DATAWIN_LOCATION_ROMFS:
            args.dataWinPath = dataWinPath;
            break;
        default:
            args.dataWinPath = "";
            printf("No valid data.win location found.\n");
            consoleUpdate(NULL);
            sleep(5);
            break;
    }
    if (sdmcMountSucceeded && dataWinFolder != NULL) {
        args.saveFolder = executableFolder;
    } else {
        args.saveFolder = "";
    }

    consoleUpdate(NULL);
    consoleExit(NULL);

    int ret = loop(args, argv[0]);
    freeCommandLineArgs(&args);
    if (sdmcMountSucceeded) {
        switchCloseLogFile();
        fsdevUnmountDevice("sdmc");
    }
    if (romFsInitSucceeded) romfsExit();
    return ret;
}
