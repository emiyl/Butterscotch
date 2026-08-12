set(CMAKE_SYSTEM_NAME Windows)
set(CMAKE_SYSTEM_PROCESSOR ARM64)

set(CMAKE_C_COMPILER aarch64-w64-mingw32-clang)
set(CMAKE_CXX_COMPILER aarch64-w64-mingw32-clang++)
set(CMAKE_RC_COMPILER aarch64-w64-mingw32-windres)

set(CMAKE_AR aarch64-w64-mingw32-llvm-ar)
set(CMAKE_RANLIB aarch64-w64-mingw32-llvm-ranlib)

set(CMAKE_FIND_ROOT_PATH
    /usr/aarch64-w64-mingw32
    /opt/llvm-mingw/aarch64-w64-mingw32
)

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)