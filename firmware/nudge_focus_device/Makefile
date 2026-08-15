CXX ?= clang++
CXXFLAGS := -std=c++17 -Wall -Wextra -Werror -Iinclude
BUILD_DIR := build/native
TEST_BINARY := $(BUILD_DIR)/nudge_focus_core_test
SOURCES := src/focus_session.cpp src/protocol_json.cpp test/native/focus_session_test.cpp

.PHONY: test clean

test: $(TEST_BINARY)
	$(TEST_BINARY)

$(TEST_BINARY): $(SOURCES)
	mkdir -p $(BUILD_DIR)
	$(CXX) $(CXXFLAGS) $(SOURCES) -o $(TEST_BINARY)

clean:
	rm -f $(TEST_BINARY)
