#include "string_compat.h"
#include "stdio_compat.h"
#include <time.h>
#include "math_compat.h"

#include <windows.h>
#include <windowsx.h>
#include <xinput.h>
#include <gl/gl.h>

#include "common.h"
#include "input_recording.h"
#include "desktop/platformdefs.h"
#include "gettime.h"
#include "runner_mouse.h"

#ifndef DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2
#define DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2 ((HANDLE)-4)
#endif

typedef HGLRC (WINAPI *PFNWGLCREATECONTEXTATTRIBSARBPROC)(HDC, HGLRC, const int*);
typedef BOOL  (WINAPI *PFNWGLCHOOSEPIXELFORMATARBPROC)(HDC, const int*, const FLOAT*, UINT, int*, UINT*);
typedef BOOL  (WINAPI *PFNWGLSWAPINTERVALEXTPROC)(int);

#define WGL_CONTEXT_MAJOR_VERSION_ARB   0x2091
#define WGL_CONTEXT_MINOR_VERSION_ARB   0x2092
#define WGL_CONTEXT_PROFILE_MASK_ARB    0x9126
#define WGL_CONTEXT_FLAGS_ARB           0x2094
#define WGL_CONTEXT_DEBUG_BIT_ARB       0x0001
#define WGL_CONTEXT_COMPATIBILITY_PROFILE_BIT_ARB 0x0002
#define WGL_CONTEXT_CORE_PROFILE_BIT_ARB           0x0001
#define WGL_DRAW_TO_WINDOW_ARB   0x2001
#define WGL_SUPPORT_OPENGL_ARB   0x2010
#define WGL_DOUBLE_BUFFER_ARB    0x2011
#define WGL_PIXEL_TYPE_ARB       0x2013
#define WGL_TYPE_RGBA_ARB        0x202B
#define WGL_COLOR_BITS_ARB       0x2014
#define WGL_DEPTH_BITS_ARB       0x2022
#define WGL_STENCIL_BITS_ARB     0x2023

static PFNWGLCREATECONTEXTATTRIBSARBPROC wglCreateContextAttribsARB_;
static PFNWGLCHOOSEPIXELFORMATARBPROC    wglChoosePixelFormatARB_;
static PFNWGLSWAPINTERVALEXTPROC         wglSwapIntervalEXT_;

static HWND   g_hwnd;
static HDC    g_hdc;
static HGLRC  g_hglrc;
static Runner *g_runner;
static bool   g_shouldClose = false;
static WCHAR  g_charHighSurrogate = 0;

static const wchar_t* kWindowClassName = L"ButterscotchWindowClass";

static float windowDpiScale(HWND hwnd) {
    UINT dpi = GetDpiForWindow(hwnd);
    float scaleDiv = 96.0f * 4;
    return dpi > 0 ? (float)dpi / scaleDiv : 1.0f;
}

static void framebufferToLogical(float xs, float ys, int fbW, int fbH, int* outW, int* outH) {
    *outW = (xs > 0.0f) ? (int) ceilf((float) fbW / xs) : fbW;
    *outH = (ys > 0.0f) ? (int) ceilf((float) fbH / ys) : fbH;
}

static LRESULT CALLBACK wndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    switch (msg) {
        case WM_CLOSE:
            g_shouldClose = true;
            return 0;

        case WM_DESTROY:
            g_shouldClose = true;
            return 0;

        case WM_KEYDOWN:
        case WM_SYSKEYDOWN: {
            if (InputRecording_isPlaybackActive(globalInputRecording)) return 0;
            if (wParam >= 0) RunnerKeyboard_onKeyDown(g_runner->keyboard, wParam);
            return (msg == WM_SYSKEYDOWN) ? DefWindowProcW(hwnd, msg, wParam, lParam) : 0;
        }

        case WM_KEYUP:
        case WM_SYSKEYUP: {
            if (InputRecording_isPlaybackActive(globalInputRecording)) return 0;
            if (wParam >= 0) RunnerKeyboard_onKeyUp(g_runner->keyboard, wParam);
            return (msg == WM_SYSKEYUP) ? DefWindowProcW(hwnd, msg, wParam, lParam) : 0;
        }

        case WM_CHAR: {
            if (InputRecording_isPlaybackActive(globalInputRecording)) return 0;
            WCHAR unit = (WCHAR)wParam;
            if (unit >= 0xD800 && unit <= 0xDBFF) {
                // High surrogate: stash and wait for its pair.
                g_charHighSurrogate = unit;
                return 0;
            }
            unsigned int codepoint;
            if (unit >= 0xDC00 && unit <= 0xDFFF && g_charHighSurrogate) {
                codepoint = 0x10000
                    + ((unsigned int)(g_charHighSurrogate - 0xD800) << 10)
                    + (unsigned int)(unit - 0xDC00);
                g_charHighSurrogate = 0;
            } else {
                codepoint = unit;
                g_charHighSurrogate = 0;
            }
            RunnerKeyboard_onCharacter(g_runner->keyboard, codepoint);
            return 0;
        }

        case WM_LBUTTONDOWN: RunnerMouse_onButtonDown(g_runner->mouse, GML_MB_LEFT);   return 0;
        case WM_LBUTTONUP:   RunnerMouse_onButtonUp(g_runner->mouse, GML_MB_LEFT);     return 0;
        case WM_RBUTTONDOWN: RunnerMouse_onButtonDown(g_runner->mouse, GML_MB_RIGHT);  return 0;
        case WM_RBUTTONUP:   RunnerMouse_onButtonUp(g_runner->mouse, GML_MB_RIGHT);    return 0;
        case WM_MBUTTONDOWN: RunnerMouse_onButtonDown(g_runner->mouse, GML_MB_MIDDLE); return 0;
        case WM_MBUTTONUP:   RunnerMouse_onButtonUp(g_runner->mouse, GML_MB_MIDDLE);   return 0;

        case WM_MOUSEWHEEL: {
            double delta = (double)GET_WHEEL_DELTA_WPARAM(wParam) / (double)WHEEL_DELTA;
            RunnerMouse_onWheel(g_runner->mouse, delta);
            return 0;
        }

#ifdef ENABLE_SW_RENDERER
        case WM_SIZE: {
            if (gfx == SOFTWARE) {
                int w = LOWORD(lParam), h = HIWORD(lParam);
                if (g_hglrc && wglGetCurrentContext()) glViewport(0, 0, w, h);
            }
            return 0;
        }
#endif

        case WM_SETCURSOR: {
            if (LOWORD(lParam) == HTCLIENT && g_runner && g_runner->currentCursor == GML_CR_NONE) {
                SetCursor(NULL);
                return TRUE;
            }
            break;
        }

        default: break;
    }
    return DefWindowProcW(hwnd, msg, wParam, lParam);
}

static bool loadWglExtensions(HINSTANCE hInstance) {
    WNDCLASSEXW wc = {0};
    wc.cbSize = sizeof(wc);
    wc.lpfnWndProc = DefWindowProcW;
    wc.hInstance = hInstance;
    wc.lpszClassName = L"ButterscotchWglLoader";
    RegisterClassExW(&wc);

    HWND dummy = CreateWindowExW(0, wc.lpszClassName, L"", 0, 0, 0, 1, 1, NULL, NULL, hInstance, NULL);
    if (!dummy) return false;
    HDC dummyDc = GetDC(dummy);

    PIXELFORMATDESCRIPTOR pfd = {0};
    pfd.nSize = sizeof(pfd);
    pfd.nVersion = 1;
    pfd.dwFlags = PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER;
    pfd.iPixelType = PFD_TYPE_RGBA;
    pfd.cColorBits = 32;
    pfd.cDepthBits = 24;
    pfd.cStencilBits = 8;

    int fmt = ChoosePixelFormat(dummyDc, &pfd);
    bool ok = fmt != 0 && SetPixelFormat(dummyDc, fmt, &pfd);
    HGLRC dummyRc = ok ? wglCreateContext(dummyDc) : NULL;
    if (dummyRc) {
        wglMakeCurrent(dummyDc, dummyRc);
        wglCreateContextAttribsARB_ = (PFNWGLCREATECONTEXTATTRIBSARBPROC) wglGetProcAddress("wglCreateContextAttribsARB");
        wglChoosePixelFormatARB_    = (PFNWGLCHOOSEPIXELFORMATARBPROC) wglGetProcAddress("wglChoosePixelFormatARB");
        wglSwapIntervalEXT_         = (PFNWGLSWAPINTERVALEXTPROC) wglGetProcAddress("wglSwapIntervalEXT");
        wglMakeCurrent(NULL, NULL);
        wglDeleteContext(dummyRc);
    }
    ReleaseDC(dummy, dummyDc);
    DestroyWindow(dummy);
    UnregisterClassW(wc.lpszClassName, hInstance);
    return wglCreateContextAttribsARB_ != NULL;
}

static HGLRC createGlContext(HDC hdc) {
    int pixelFormat = 0;
    UINT numFormats = 0;

    if (wglChoosePixelFormatARB_) {
        int attribs[] = {
            WGL_DRAW_TO_WINDOW_ARB, TRUE,
            WGL_SUPPORT_OPENGL_ARB, TRUE,
            WGL_DOUBLE_BUFFER_ARB,  TRUE,
            WGL_PIXEL_TYPE_ARB,     WGL_TYPE_RGBA_ARB,
            WGL_COLOR_BITS_ARB,     32,
            WGL_DEPTH_BITS_ARB,     24,
            WGL_STENCIL_BITS_ARB,   8,
            0
        };
        wglChoosePixelFormatARB_(hdc, attribs, NULL, 1, &pixelFormat, &numFormats);
    }
    if (pixelFormat == 0 || numFormats == 0) {
        PIXELFORMATDESCRIPTOR pfd = {0};
        pfd.nSize = sizeof(pfd);
        pfd.nVersion = 1;
        pfd.dwFlags = PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER;
        pfd.iPixelType = PFD_TYPE_RGBA;
        pfd.cColorBits = 32;
        pfd.cDepthBits = 24;
        pfd.cStencilBits = 8;
        pixelFormat = ChoosePixelFormat(hdc, &pfd);
        if (pixelFormat == 0) return NULL;
        PIXELFORMATDESCRIPTOR chosen;
        DescribePixelFormat(hdc, pixelFormat, sizeof(chosen), &chosen);
        if (!SetPixelFormat(hdc, pixelFormat, &chosen)) return NULL;
    } else {
        PIXELFORMATDESCRIPTOR pfd = {0};
        DescribePixelFormat(hdc, pixelFormat, sizeof(pfd), &pfd);
        if (!SetPixelFormat(hdc, pixelFormat, &pfd)) return NULL;
    }

    if (gfx == SOFTWARE || gfx == LEGACY_GL) {
        return wglCreateContext(hdc);
    }

    if (!wglCreateContextAttribsARB_) {
        return wglCreateContext(hdc);
    }

    for (size_t i = 0; i < sizeof(GLCommon_versions)/sizeof(GLCommon_versions[0]); i++) {
        int flags = 0;
#ifndef NDEBUG
        flags |= WGL_CONTEXT_DEBUG_BIT_ARB;
#endif
        int profileBit = (GLCommon_versions[i].major >= 3 && !(GLCommon_versions[i].major == 3 && GLCommon_versions[i].minor < 2))
            ? WGL_CONTEXT_COMPATIBILITY_PROFILE_BIT_ARB
            : WGL_CONTEXT_COMPATIBILITY_PROFILE_BIT_ARB;

        int attribs[] = {
            WGL_CONTEXT_MAJOR_VERSION_ARB, GLCommon_versions[i].major,
            WGL_CONTEXT_MINOR_VERSION_ARB, GLCommon_versions[i].minor,
            WGL_CONTEXT_PROFILE_MASK_ARB,  profileBit,
            WGL_CONTEXT_FLAGS_ARB,         flags,
            0
        };
        HGLRC rc = wglCreateContextAttribsARB_(hdc, NULL, attribs);
        if (rc) return rc;
    }
    return NULL;
}

void platformSetWindowTitle(const char* title) {
    char windowTitle[256];
    snprintf(windowTitle, sizeof(windowTitle), "%s", title);
    SetWindowTextA(g_hwnd, windowTitle);
}

bool platformGetWindowSize(int32_t* outW, int32_t* outH) {
    if (!outW || !outH || !g_hwnd) return false;
    RECT rc;
    if (!GetClientRect(g_hwnd, &rc)) return false;
    int w = rc.right - rc.left;
    int h = rc.bottom - rc.top;
    if (w <= 0 || h <= 0) return false;
    *outW = w;
    *outH = h;
    return true;
}

bool platformGetScaledWindowSize(int32_t* outW, int32_t* outH) {
    if (!outW || !outH || !g_hwnd) return false;
    int32_t fbW, fbH;
    if (!platformGetWindowSize(&fbW, &fbH)) return false;
    float scale = windowDpiScale(g_hwnd);
    *outW = scale > 0.0f ? (int32_t)(fbW / scale) : fbW;
    *outH = scale > 0.0f ? (int32_t)(fbH / scale) : fbH;
    return true;
}

void platformSetWindowSize(int32_t width, int32_t height) {
    if (width <= 0 || height <= 0 || !g_hwnd) return;
    float scale = windowDpiScale(g_hwnd);
    int logicalW, logicalH;
    framebufferToLogical(scale, scale, width, height, &logicalW, &logicalH);

    RECT rc = {0, 0, logicalW, logicalH};
    DWORD style = (DWORD)GetWindowLongPtrW(g_hwnd, GWL_STYLE);
    DWORD exStyle = (DWORD)GetWindowLongPtrW(g_hwnd, GWL_EXSTYLE);
    AdjustWindowRectExForDpi(&rc, style, FALSE, exStyle, GetDpiForWindow(g_hwnd));

    SetWindowPos(g_hwnd, NULL, 0, 0, rc.right - rc.left, rc.bottom - rc.top,
                 SWP_NOMOVE | SWP_NOZORDER | SWP_NOACTIVATE);
}

void platformGetMousePos(double *xPos, double *yPos) {
    if (!xPos || !yPos || !g_hwnd) return;
    POINT p;
    GetCursorPos(&p);
    ScreenToClient(g_hwnd, &p);
    *xPos = (double)p.x;
    *yPos = (double)p.y;
}

static bool platformGetWindowFocus(void) {
    return GetForegroundWindow() == g_hwnd;
}

bool platformInit(int32_t reqW, int32_t reqH, const char *title, bool headless) {
    SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);

    HINSTANCE hInstance = GetModuleHandleW(NULL);

    if (!loadWglExtensions(hInstance)) {
        logWarn("Failed to resolve WGL extension functions, falling back to legacy context creation\n");
    }

    WNDCLASSEXW wc = {0};
    wc.cbSize = sizeof(wc);
    wc.style = CS_OWNDC | CS_HREDRAW | CS_VREDRAW;
    wc.lpfnWndProc = wndProc;
    wc.hInstance = hInstance;
    // wc.hCursor = LoadCursorW(NULL, IDC_ARROW);
    wc.lpszClassName = kWindowClassName;
    if (!RegisterClassExW(&wc)) {
        logError("Failed to register window class\n");
        return false;
    }

    int titleLen = MultiByteToWideChar(CP_UTF8, 0, title, -1, NULL, 0);
    WCHAR* wtitle = (WCHAR*) malloc(sizeof(WCHAR) * titleLen);
    MultiByteToWideChar(CP_UTF8, 0, title, -1, wtitle, titleLen);

    char fullTitle[256];
    snprintf(fullTitle, sizeof(fullTitle), "Butterscotch - %s", title);
    int fullTitleLen = MultiByteToWideChar(CP_UTF8, 0, fullTitle, -1, NULL, 0);
    WCHAR* wFullTitle = (WCHAR*) malloc(sizeof(WCHAR) * fullTitleLen);
    MultiByteToWideChar(CP_UTF8, 0, fullTitle, -1, wFullTitle, fullTitleLen);

    DWORD style = WS_OVERLAPPEDWINDOW;
    g_hwnd = CreateWindowExW(0, kWindowClassName, wFullTitle, style,
                              CW_USEDEFAULT, CW_USEDEFAULT, reqW, reqH,
                              NULL, NULL, hInstance, NULL);
    free(wtitle);
    free(wFullTitle);

    if (!g_hwnd) {
        logError("Failed to create window\n");
        return false;
    }

    g_hdc = GetDC(g_hwnd);
    g_hglrc = createGlContext(g_hdc);
    if (!g_hglrc) {
        logError("Failed to create OpenGL context\n");
        DestroyWindow(g_hwnd);
        g_hwnd = NULL;
        return false;
    }
    wglMakeCurrent(g_hdc, g_hglrc);

    if (wglSwapIntervalEXT_) wglSwapIntervalEXT_(0); // Disable v-sync, we control timing ourselves

    platformSetWindowSize(reqW, reqH);

    ShowWindow(g_hwnd, headless ? SW_HIDE : SW_SHOW);
    UpdateWindow(g_hwnd);

    return true;
}

void platformExit(void) {
    if (g_hglrc) {
        wglMakeCurrent(NULL, NULL);
        wglDeleteContext(g_hglrc);
        g_hglrc = NULL;
    }
    if (g_hdc) {
        ReleaseDC(g_hwnd, g_hdc);
        g_hdc = NULL;
    }
    if (g_hwnd) {
        DestroyWindow(g_hwnd);
        g_hwnd = NULL;
    }
    UnregisterClassW(kWindowClassName, GetModuleHandleW(NULL));
}

static void platformSetCursor(int32_t cursorType) {
    if (cursorType == GML_CR_NONE) {
        SetCursor(NULL);
        return;
    }

    // LPCWSTR shape;
    switch (cursorType) {
        // case GML_CR_CROSS:      shape = IDC_CROSS;    break;
        // case GML_CR_BEAM:       shape = IDC_IBEAM;    break;
        // case GML_CR_SIZE_NS:    shape = IDC_SIZENS;   break;
        // case GML_CR_SIZE_WE:    shape = IDC_SIZEWE;   break;
        // case GML_CR_DRAG:       shape = IDC_HAND;     break;
        // case GML_CR_HANDPOINT:  shape = IDC_HAND;     break;
        // case GML_CR_SIZE_ALL:   shape = IDC_SIZEALL;  break;
        // case GML_CR_SIZE_NWSE:  shape = IDC_SIZENWSE; break;
        // case GML_CR_SIZE_NESW:  shape = IDC_SIZENESW; break;
        // default:                shape = IDC_ARROW;    break;
    }
    // SetCursor(LoadCursorW(NULL, shape));
}

void platformInitFunctions(Runner *runner) {
    g_runner = runner;
    runner->windowHasFocus = platformGetWindowFocus;
    runner->setCursor = platformSetCursor;
    runner->currentCursor = GML_CR_DEFAULT;
}

#ifdef ENABLE_SW_RENDERER

static uint32_t* nextFb = NULL;
static int fbWidth = 0, fbHeight = 0;

void Runner_setNextFrame(uint32_t* framebuffer, int width, int height) {
    nextFb = framebuffer;
    fbWidth = width;
    fbHeight = height;
}

#endif

void platformSwapBuffers(void) {
#ifdef ENABLE_SW_RENDERER
    if (gfx == SOFTWARE && nextFb) {
        glRasterPos2f(-1, 1);
        glPixelZoom(1, -1);
        glDrawPixels(fbWidth, fbHeight, GL_BGRA_EXT, GL_UNSIGNED_BYTE, nextFb);
        nextFb = NULL;
    }
#endif
    SwapBuffers(g_hdc);
}

void *platformGetProcAddress(const char *name) {
    void* p = (void*) wglGetProcAddress(name);
    // wglGetProcAddress doesn't reliably resolve pre-1.2 functions; those
    // live as static exports of opengl32.dll instead.
    if (p == NULL || p == (void*)0x1 || p == (void*)0x2 || p == (void*)0x3 || p == (void*)-1) {
        static HMODULE gl32 = NULL;
        if (!gl32) gl32 = LoadLibraryA("opengl32.dll");
        p = (void*) GetProcAddress(gl32, name);
    }
    return p;
}

double platformGetTime(void) {
    static LARGE_INTEGER freq = {0};
    static LARGE_INTEGER start = {0};
    if (freq.QuadPart == 0) {
        QueryPerformanceFrequency(&freq);
        QueryPerformanceCounter(&start);
    }
    LARGE_INTEGER now;
    QueryPerformanceCounter(&now);
    return (double)(now.QuadPart - start.QuadPart) / (double)freq.QuadPart;
}

enum {
    IDX_LT = 6,
    IDX_RT = 7,
};

static void mapXInputToGml(const XINPUT_STATE* state, GamepadSlot* slot) {
    const XINPUT_GAMEPAD* gp = &state->Gamepad;

    memcpy(slot->buttonDownPrev, slot->buttonDown, sizeof(slot->buttonDown));
    memset(slot->buttonDown, 0, sizeof(slot->buttonDown));
    memset(slot->buttonPressed, 0, sizeof(slot->buttonPressed));
    memset(slot->buttonReleased, 0, sizeof(slot->buttonReleased));
    memset(slot->buttonValue, 0, sizeof(slot->buttonValue));
    memset(slot->axisValue, 0, sizeof(slot->axisValue));

    if (gp->wButtons & XINPUT_GAMEPAD_A) slot->buttonDown[0] = true;
    if (gp->wButtons & XINPUT_GAMEPAD_B) slot->buttonDown[1] = true;
    if (gp->wButtons & XINPUT_GAMEPAD_X) slot->buttonDown[2] = true;
    if (gp->wButtons & XINPUT_GAMEPAD_Y) slot->buttonDown[3] = true;

    if (gp->wButtons & XINPUT_GAMEPAD_LEFT_SHOULDER)  slot->buttonDown[4] = true;
    if (gp->wButtons & XINPUT_GAMEPAD_RIGHT_SHOULDER) slot->buttonDown[5] = true;

    if (gp->wButtons & XINPUT_GAMEPAD_BACK)  slot->buttonDown[8] = true;
    if (gp->wButtons & XINPUT_GAMEPAD_START) slot->buttonDown[9] = true;
    // No GUIDE/Xbox-button bit in XInput; buttonDown[16] intentionally unset.

    if (gp->wButtons & XINPUT_GAMEPAD_LEFT_THUMB)  slot->buttonDown[10] = true;
    if (gp->wButtons & XINPUT_GAMEPAD_RIGHT_THUMB) slot->buttonDown[11] = true;

    if (gp->wButtons & XINPUT_GAMEPAD_DPAD_UP)    slot->buttonDown[12] = true;
    if (gp->wButtons & XINPUT_GAMEPAD_DPAD_DOWN)  slot->buttonDown[13] = true;
    if (gp->wButtons & XINPUT_GAMEPAD_DPAD_LEFT)  slot->buttonDown[14] = true;
    if (gp->wButtons & XINPUT_GAMEPAD_DPAD_RIGHT) slot->buttonDown[15] = true;

    float lt = gp->bLeftTrigger / 255.0f;
    float rt = gp->bRightTrigger / 255.0f;
    slot->buttonValue[IDX_LT] = lt;
    slot->buttonValue[IDX_RT] = rt;
    if (lt >= slot->triggerThreshold) slot->buttonDown[IDX_LT] = true;
    if (rt >= slot->triggerThreshold) slot->buttonDown[IDX_RT] = true;

    float lx = gp->sThumbLX / 32767.0f, ly = gp->sThumbLY / 32767.0f;
    float rx = gp->sThumbRX / 32767.0f, ry = gp->sThumbRY / 32767.0f;
    slot->axisValue[0] = (lx < -1.0f) ? -1.0f : (lx > 1.0f ? 1.0f : lx);
    slot->axisValue[1] = (ly < -1.0f) ? -1.0f : (ly > 1.0f ? 1.0f : ly);
    slot->axisValue[2] = (rx < -1.0f) ? -1.0f : (rx > 1.0f ? 1.0f : rx);
    slot->axisValue[3] = (ry < -1.0f) ? -1.0f : (ry > 1.0f ? 1.0f : ry);

    for (int i = 0; GP_BUTTON_COUNT > i; i++) {
        if (i == IDX_LT || i == IDX_RT) continue;
        slot->buttonValue[i] = slot->buttonDown[i] ? 1.0f : 0.0f;
    }
}

bool platformHandleEvents(void) {
    MSG msg;
    while (PeekMessageW(&msg, NULL, 0, 0, PM_REMOVE)) {
        TranslateMessage(&msg);
        DispatchMessageW(&msg);
    }

    if (g_shouldClose) return true;

    for (int slotIdx = 0; slotIdx < 1 && slotIdx < MAX_GAMEPADS; slotIdx++) {
        GamepadSlot* slot = g_runner->gamepads->slots + slotIdx;

        bool currentlyConnected = false;
        DWORD foundUserIndex = (DWORD)-1;
        XINPUT_STATE state;

        for (DWORD userIndex = 0; userIndex < XUSER_MAX_COUNT; userIndex++) {
            ZeroMemory(&state, sizeof(state));
            // if (XInputGetState(userIndex, &state) == ERROR_SUCCESS) {
            //     foundUserIndex = userIndex;
            //     currentlyConnected = true;
            //     break;
            // }
        }

        if (currentlyConnected) {
            mapXInputToGml(&state, slot);
            slot->jid = (int)foundUserIndex;
            slot->connected = true;

            snprintf(slot->description, sizeof(slot->description), "XInput Controller %lu", foundUserIndex);
            slot->guid[0] = '\0'; // XInput exposes no stable GUID like SDL/DirectInput does.
        } else {
            slot->connected = false;
            slot->guid[0] = '\0';
        }

        if (slot->connected) {
            for (int btn = 0; GP_BUTTON_COUNT > btn; btn++) {
                bool wasDown = slot->buttonDownPrev[btn];
                if (slot->buttonDown[btn] && !wasDown) slot->buttonPressed[btn] = true;
                if (!slot->buttonDown[btn] && wasDown) slot->buttonReleased[btn] = true;
            }
            g_runner->gamepads->connectedCount++;
        }
    }

    return false;
}

void platformSleepUntil(uint64_t time) {
    int64_t remaining = time - nowNanos();
    if (remaining > 2000000) {
        remaining -= 1000000;
#ifdef _WIN32
        Sleep((DWORD)(remaining / 1000000));
#else
        struct timespec ts;
        ts.tv_sec  = 0;
        ts.tv_nsec = remaining;
        nanosleep(&ts, NULL);
#endif
    }
    while (nowNanos() < time) {
        YIELD();
    }
}