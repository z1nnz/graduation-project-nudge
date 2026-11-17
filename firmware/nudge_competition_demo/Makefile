CXX ?= c++
CXXFLAGS := -std=c++17 -Wall -Wextra -Werror -Iinclude
BUILD_DIR := build/native
CORE := src/core.cpp src/drawing.cpp

.PHONY: test preview
test:
	mkdir -p $(BUILD_DIR)
	$(CXX) $(CXXFLAGS) $(CORE) test/core_test.cpp -o $(BUILD_DIR)/demo_core_test
	$(BUILD_DIR)/demo_core_test

preview:
	mkdir -p $(BUILD_DIR)
	$(CXX) $(CXXFLAGS) $(CORE) tools/preview.cpp -o $(BUILD_DIR)/demo_preview
	$(BUILD_DIR)/demo_preview $(BUILD_DIR)
