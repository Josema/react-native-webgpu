set(DAWN_XCFRAMEWORK_DIR
  ${CMAKE_CURRENT_SOURCE_DIR}/../libs/apple/libwebgpu_dawn.xcframework)

if(CMAKE_SYSTEM_NAME STREQUAL "iOS")
  if(CMAKE_OSX_SYSROOT MATCHES "iphonesimulator")
    set(DAWN_LIB
      ${DAWN_XCFRAMEWORK_DIR}/ios-arm64_x86_64-simulator/libwebgpu_dawn.a)
  else()
    set(DAWN_LIB ${DAWN_XCFRAMEWORK_DIR}/ios-arm64/libwebgpu_dawn.a)
  endif()
else()
  set(DAWN_LIB ${DAWN_XCFRAMEWORK_DIR}/macos-arm64_x86_64/libwebgpu_dawn.a)
endif()

set(IOS_NATIVE_EXAMPLE_SOURCES
  main.m
  ${CMAKE_CURRENT_SOURCE_DIR}/../apple/ApplePlatformContext.mm
  ${CMAKE_CURRENT_SOURCE_DIR}/../apple/MainQueueJSDispatcher.mm
  ${CMAKE_CURRENT_SOURCE_DIR}/../apple/MetalSurfaceHost.mm
  ${CMAKE_CURRENT_SOURCE_DIR}/../webgpu-core/third_party/jsc/JSCRuntime.cpp
)

add_executable(ios-native-example MACOSX_BUNDLE ${IOS_NATIVE_EXAMPLE_SOURCES})
set_source_files_properties(main.m PROPERTIES LANGUAGE OBJCXX)

target_include_directories(ios-native-example PRIVATE
  ${CMAKE_CURRENT_SOURCE_DIR}
  ${CMAKE_CURRENT_SOURCE_DIR}/../apple
  ${CMAKE_CURRENT_SOURCE_DIR}/../cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/../cpp/jsi
  ${CMAKE_CURRENT_SOURCE_DIR}/../cpp/rnwgpu
  ${CMAKE_CURRENT_SOURCE_DIR}/../cpp/rnwgpu/api
  ${CMAKE_CURRENT_SOURCE_DIR}/../cpp/rnwgpu/api/descriptors
  ${CMAKE_CURRENT_SOURCE_DIR}/../webgpu-core/third_party/jsi
  ${CMAKE_CURRENT_SOURCE_DIR}/../webgpu-core/third_party/jsc
)

target_link_libraries(ios-native-example PRIVATE
  webgpu-core
  ${DAWN_LIB}
  "-framework Foundation"
  "-framework QuartzCore"
  "-framework Metal"
  "-framework IOSurface"
  "-framework JavaScriptCore"
  "-framework CoreGraphics"
)

if(CMAKE_SYSTEM_NAME STREQUAL "iOS")
  target_link_libraries(ios-native-example PRIVATE "-framework UIKit")
  set_target_properties(ios-native-example PROPERTIES
    MACOSX_BUNDLE_INFO_PLIST ${CMAKE_CURRENT_SOURCE_DIR}/Info.plist
    MACOSX_BUNDLE_GUI_IDENTIFIER com.webgpu.iosnativeexample
    XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER "com.webgpu.iosnativeexample"
    XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED "NO"
    XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED "NO"
    XCODE_ATTRIBUTE_CLANG_ENABLE_OBJC_ARC "YES"
  )
else()
  target_link_libraries(ios-native-example PRIVATE "-framework AppKit")
endif()

set_target_properties(ios-native-example PROPERTIES
  XCODE_ATTRIBUTE_CLANG_CXX_LANGUAGE_STANDARD "c++20"
)
