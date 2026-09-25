# CMakeLists.txt for the MP3 encoder JNI bridge.
#
# This assumes libmp3lame's source has been vendored under
# android/app/src/main/cpp/lame/ (a `libmp3lame` subfolder containing its
# own CMakeLists.txt, or its headers under lame/include plus a prebuilt
# static library — either layout works, adjust the two lines marked below
# to match whichever you vendor). See lame_jni.cpp's header comment for
# why that source isn't included directly in this project.

cmake_minimum_required(VERSION 3.22.1)
project("craunch_mp3_encoder")

# --- Option A: building libmp3lame from vendored source -------------------
# Uncomment if android/app/src/main/cpp/lame/ contains LAME's own source
# tree with a CMakeLists.txt (several community mirrors of LAME ship one).
# add_subdirectory(lame)

# --- Option B: linking a prebuilt libmp3lame.a / libmp3lame.so ------------
# Point this at wherever your prebuilt binaries for each ABI live, e.g.
# under android/app/src/main/cpp/lame/prebuilt/${ANDROID_ABI}/.
add_library(mp3lame STATIC IMPORTED)
set_target_properties(mp3lame PROPERTIES
    IMPORTED_LOCATION "${CMAKE_SOURCE_DIR}/lame/prebuilt/${ANDROID_ABI}/libmp3lame.a"
)

include_directories("${CMAKE_SOURCE_DIR}/lame/include")

add_library(
        craunch_mp3_encoder
        SHARED
        lame_jni.cpp
)

find_library(log-lib log)

target_link_libraries(
        craunch_mp3_encoder
        mp3lame
        ${log-lib}
)
