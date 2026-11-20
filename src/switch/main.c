#include <loop.h>
#include <switch.h>
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

bool romFsInitSucceeded = false;
bool sdmcMountSucceeded = false;

DataWinLocation GetDataWinLoadType() {
    Result res;
    struct stat s;

    printf("Initializing RomFS...\n");
    res = romfsInit();
    if (R_SUCCEEDED(res)) {
        romFsInitSucceeded = true;
        printf("RomFS initialized successfully.\n");
        if (stat("romfs:/data.win", &s) == 0) {
            printf("Found data.win in RomFS.\n");
            return DATAWIN_LOCATION_ROMFS;
        }
    } else {
        printf("Failed to initialize RomFS: 0x%x\n", res);
    }

    printf("Initializing SDMC...\n");
    res = fsdevMountSdmc();
    if (R_SUCCEEDED(res)) {
        printf("SDMC initialized successfully.\n");
        sdmcMountSucceeded = true;
        if (stat("sdmc:/switch/butterscotch/data.win", &s) == 0) {
            printf("Found data.win in SDMC.\n");
            return DATAWIN_LOCATION_SDMC;
        }
    } else {
        printf("Failed to initialize SDMC: 0x%x\n", res);
    }

    return DATAWIN_LOCATION_NONE;
}

int main(int argc, char* argv[]) {
    (void)argc;
    setbuf(stdout, NULL);
    setbuf(stderr, NULL);

    DataWinLocation dataWinLocation = GetDataWinLoadType();

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
            args.dataWinPath = "sdmc:/switch/butterscotch/data.win";
            break;
        case DATAWIN_LOCATION_ROMFS:
            args.dataWinPath = "romfs:/data.win";
            break;
        default:
            args.dataWinPath = "";
            break;
    }
    if (sdmcMountSucceeded) {
        args.saveFolder = "sdmc:/switch/butterscotch";
    } else {
        args.saveFolder = "";
    }

    consoleExit(NULL);

    int ret = loop(args, argv[0]);
    freeCommandLineArgs(&args);
    if (sdmcMountSucceeded) fsdevUnmountDevice("sdmc");
    if (romFsInitSucceeded) romfsExit();
    return ret;
}
