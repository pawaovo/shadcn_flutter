cmake_minimum_required(VERSION 3.13)
project(runner LANGUAGES CXX)

# Define the application target. To change its name, change BINARY_NAME in the
# top-level CMakeLists.txt, not the value here, or `flutter run` will no longer
# work.
#
# Any new source files that you add to the application should be added here.
add_executable(${BINARY_NAME}
  "main.cc"
  "my_application.cc"
  "accessibility_bridge.cc"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
)

# Apply the standard set of build settings. This can be removed for applications
# that need different build settings.
apply_standard_settings(${BINARY_NAME})

# Add preprocessor definitions for the application ID.
add_definitions(-DAPPLICATION_ID="${APPLICATION_ID}")

# Add dependency libraries. Add any application-specific dependencies here.
target_link_libraries(${BINARY_NAME} PRIVATE flutter)
target_link_libraries(${BINARY_NAME} PRIVATE PkgConfig::GTK)

target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")

# Explicit CI-only probe. It links the runtime from the prior ordinary Flutter
# build without another flutter_assemble invocation or a bundle installation.
add_library(catalog_probe_flutter_runtime SHARED IMPORTED)
set_target_properties(catalog_probe_flutter_runtime PROPERTIES
  IMPORTED_LOCATION "${FLUTTER_LIBRARY}"
  INTERFACE_INCLUDE_DIRECTORIES "${FLUTTER_MANAGED_DIR}/ephemeral"
)
add_executable(catalog_accessibility_bridge_probe EXCLUDE_FROM_ALL
  "accessibility_bridge_probe.cc"
  "accessibility_bridge.cc"
)
apply_standard_settings(catalog_accessibility_bridge_probe)
target_link_libraries(catalog_accessibility_bridge_probe PRIVATE
  catalog_probe_flutter_runtime PkgConfig::GTK
)
set_target_properties(catalog_accessibility_bridge_probe PROPERTIES
  RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/native_bridge_probe"
)
