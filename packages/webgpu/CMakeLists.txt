cmake_minimum_required(VERSION 3.24)

project(webgpu_native LANGUAGES C CXX OBJC OBJCXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

add_subdirectory(webgpu-core)

if(APPLE)
  add_subdirectory(ios-native-example)
endif()
