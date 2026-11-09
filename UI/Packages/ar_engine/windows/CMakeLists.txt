cmake_minimum_required(VERSION 3.14)

set(PLUGIN_NAME "ar_engine_plugin")

add_library(${PLUGIN_NAME} SHARED
  "src/ar_engine_plugin.cpp"
)

apply_standard_settings(${PLUGIN_NAME})

set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden
)

target_compile_definitions(${PLUGIN_NAME} PRIVATE
  FLUTTER_PLUGIN_IMPL
)

target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include"
)

target_link_libraries(${PLUGIN_NAME} PRIVATE
  flutter
  flutter_wrapper_plugin
  dxgi
  d3d11
  dxguid
)

# Platform-specific webcam via Media Foundation
if(WIN32)
  target_link_libraries(${PLUGIN_NAME} PRIVATE mf mfreadwrite mfuuid)
endif()

set(ar_engine_bundled_libraries
  ""
  PARENT_SCOPE
)
