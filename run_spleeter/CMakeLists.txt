cmake_minimum_required(VERSION 3.28)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_TOOLCHAIN_FILE "${CMAKE_CURRENT_SOURCE_DIR}/modules/vcpkg/scripts/buildsystems/vcpkg.cmake"
        CACHE STRING "Vcpkg toolchain file")
set(VCPKG_TARGET_TRIPLET "x64-windows-static" CACHE STRING "Vcpkg target triplet")

project("run_spleeter" LANGUAGES C CXX)

add_executable(${PROJECT_NAME}    
        src/main.cpp
        src/begin_demucs.cpp
        src/check_demucs.cpp

        include/begin_demucs.hpp
        include/check_demucs.hpp
        )

target_include_directories(${PROJECT_NAME} PRIVATE include)

# libarchive

find_package(LibArchive REQUIRED)

target_link_libraries(${PROJECT_NAME} PRIVATE LibArchive::LibArchive)

install(TARGETS ${PROJECT_NAME}
        RUNTIME DESTINATION ${CMAKE_CURRENT_SOURCE_DIR}/bin
        )
