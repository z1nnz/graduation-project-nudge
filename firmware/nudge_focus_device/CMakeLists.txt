cmake_minimum_required(VERSION 3.20)
project(nudge_focus_device_core LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

add_library(nudge_focus_core
  src/ambient_brightness.cpp
  src/device_context.cpp
  src/device_visuals.cpp
  src/durable_focus_transition.cpp
  src/focus_session.cpp
  src/pending_event_store.cpp
  src/protocol_json.cpp
)
target_include_directories(nudge_focus_core PUBLIC include)
target_compile_options(nudge_focus_core PRIVATE -Wall -Wextra -Werror)

add_executable(nudge_focus_core_test test/native/focus_session_test.cpp)
target_link_libraries(nudge_focus_core_test PRIVATE nudge_focus_core)
target_compile_options(nudge_focus_core_test PRIVATE -Wall -Wextra -Werror)

enable_testing()
add_test(NAME nudge_focus_core_test COMMAND nudge_focus_core_test)
