cmake_minimum_required(VERSION 3.23)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_TOOLCHAIN_FILE "${CMAKE_CURRENT_SOURCE_DIR}/modules/vcpkg/scripts/buildsystems/vcpkg.cmake"
        CACHE STRING "Vcpkg toolchain file")

set(BINARY_SUFFIX "" CACHE STRING "String to append to end of binary file")

project("run_demucs" LANGUAGES C CXX)

set(CMD_SRC
        script/install-demucs-nvidia.bat
        script/install-demucs.bat

        script/install-demucs-nvidia.sh
        script/install-demucs.sh  

        script/run-demucs.bat
        script/run-demucs.sh
)

add_executable(${PROJECT_NAME}    
        include/extract_tar_gz.hpp

        
        src/main.cpp
        src/extract_tar_gz.cpp


        ${CMD_SRC}
        )

target_include_directories(${PROJECT_NAME} PRIVATE include)

if(${BINARY_SUFFIX})
        set_target_properties(${PROJECT_NAME} PROPERTIES OUTPUT_NAME "${PROJECT_NAME}${BINARY_SUFFIX}")
endif()

# libarchive

find_package(LibArchive REQUIRED)

target_link_libraries(${PROJECT_NAME} PRIVATE LibArchive::LibArchive)

install(TARGETS ${PROJECT_NAME}
        RUNTIME DESTINATION ${CMAKE_CURRENT_BINARY_DIR}/install
        )

# asio

find_package(asio CONFIG REQUIRED)
target_link_libraries(${PROJECT_NAME} PRIVATE asio::asio)

#fmt

find_package(fmt CONFIG REQUIRED)
target_link_libraries(${PROJECT_NAME} PRIVATE fmt::fmt-header-only)
