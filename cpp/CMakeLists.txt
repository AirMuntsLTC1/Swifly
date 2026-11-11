cmake_minimum_required(VERSION 3.22.1)
project(swifly_core LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_library(swifly_core SHARED swifly_core.cpp)
target_compile_options(swifly_core PRIVATE -O2 -fvisibility=hidden)
