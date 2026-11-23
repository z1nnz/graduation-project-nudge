CXX ?= c++
CXXFLAGS := -std=c++17 -Wall -Wextra -Werror -Iinclude
BUILD_DIR := build/native
CORE := src/core.cpp src/drawing.cpp src/station.cpp src/hardware_profile.cpp src/peripherals.cpp src/character.cpp src/ble_protocol.cpp

.PHONY: test preview station-preview
test:
	mkdir -p $(BUILD_DIR)
	$(CXX) $(CXXFLAGS) $(CORE) test/core_test.cpp -o $(BUILD_DIR)/demo_core_test
	$(BUILD_DIR)/demo_core_test
	$(CXX) $(CXXFLAGS) $(CORE) test/station_peripheral_test.cpp -o $(BUILD_DIR)/station_peripheral_test
	$(BUILD_DIR)/station_peripheral_test
	$(CXX) $(CXXFLAGS) $(CORE) test/demo_control_visual_test.cpp -o $(BUILD_DIR)/demo_control_visual_test
	$(BUILD_DIR)/demo_control_visual_test

preview:
	mkdir -p $(BUILD_DIR)
	$(CXX) $(CXXFLAGS) $(CORE) tools/preview.cpp -o $(BUILD_DIR)/demo_preview
	$(BUILD_DIR)/demo_preview $(BUILD_DIR)

station-preview: preview
	$(BUILD_DIR)/demo_preview $(BUILD_DIR) station
