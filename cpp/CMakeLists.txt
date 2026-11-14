cmake_minimum_required(VERSION 3.22.1)
project(swifly_core LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# --- Embed the PHP media pipeline (cpp/php/*.php) into the library ---------------
file(GLOB SWIFLY_PHP_FILES ${CMAKE_CURRENT_SOURCE_DIR}/php/*.php)
set(SWIFLY_PHP_HEADER ${CMAKE_CURRENT_BINARY_DIR}/php_embedded.h)
file(WRITE ${SWIFLY_PHP_HEADER}
     "#pragma once\nstruct PhpFile { const char* name; const char* source; };\nstatic const PhpFile kPhpFiles[] = {\n")
foreach(php_file ${SWIFLY_PHP_FILES})
  get_filename_component(php_name ${php_file} NAME)
  file(READ ${php_file} php_source)
  file(APPEND ${SWIFLY_PHP_HEADER}
       "{\"${php_name}\", R\"SWIFLYPHP(${php_source})SWIFLYPHP\"},\n")
endforeach()
file(APPEND ${SWIFLY_PHP_HEADER} "{nullptr, nullptr}};\n")
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS ${SWIFLY_PHP_FILES})

add_library(swifly_core SHARED swifly_core.cpp media_bridge.cpp)
target_include_directories(swifly_core PRIVATE ${CMAKE_CURRENT_BINARY_DIR})
target_compile_options(swifly_core PRIVATE -O2 -fvisibility=hidden)
