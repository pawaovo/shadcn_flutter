cmake_minimum_required(VERSION 3.16)
project(flutter_atk_source_test LANGUAGES CXX)

find_package(PkgConfig REQUIRED)
pkg_check_modules(GTK REQUIRED IMPORTED_TARGET gtk+-3.0)
find_package(GTest REQUIRED)
if(NOT EXISTS "${SDK_SOURCE_ROOT}/flutter/shell/platform/linux/fl_accessible_node.h")
  message(FATAL_ERROR "SDK_SOURCE_ROOT must identify the pinned engine/src tree")
endif()
if(NOT EXISTS "${NODE_SOURCE}")
  message(FATAL_ERROR "NODE_SOURCE must identify the complete original or patched SDK .cc")
endif()

add_executable(atk_source_test
  "${NODE_SOURCE}"
  native_source_test.cc
  engine_link_stubs.cc
)
target_compile_features(atk_source_test PRIVATE cxx_std_17)
target_compile_definitions(atk_source_test PRIVATE FLUTTER_LINUX_COMPILATION)
target_compile_options(atk_source_test PRIVATE -Wall -Wextra -Werror -Wno-unused-parameter)
target_include_directories(atk_source_test PRIVATE "${SDK_SOURCE_ROOT}")
target_link_libraries(atk_source_test PRIVATE PkgConfig::GTK GTest::gtest_main)
