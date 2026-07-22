cmake_minimum_required(VERSION 3.20)

project(installer C)

set(CMAKE_C_STANDARD 11)

add_executable(file
        install.c
        installer-functions.c
)

find_package(CURL REQUIRED)

target_link_libraries(file PRIVATE CURL::libcurl)
