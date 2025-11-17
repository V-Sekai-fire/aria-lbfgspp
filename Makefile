# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

.PHONY: all clean

# Get Erlang/Elixir paths
ERL_EI_INCLUDE_DIR ?= $(shell erl -eval 'io:format("~s", [lists:concat([code:root_dir(), "/usr/include"])])' -s init stop -noshell)
ERL_EI_LIB_DIR ?= $(shell erl -eval 'io:format("~s", [lists:concat([code:root_dir(), "/usr/lib"])])' -s init stop -noshell)

# LBFGS++ paths
LBFGSPP_INCLUDE_DIR = $(CURDIR)/thirdparty/LBFGSpp/include
EIGEN_INCLUDE_DIR = $(CURDIR)/thirdparty/eigen

# Compiler flags
CXXFLAGS = -fPIC -O3 -Wall -Wextra
CXXFLAGS += -I$(ERL_EI_INCLUDE_DIR)
CXXFLAGS += -I$(LBFGSPP_INCLUDE_DIR)
CXXFLAGS += -I$(EIGEN_INCLUDE_DIR)
CXXFLAGS += -std=c++14

# Linker flags
# On macOS, NIF symbols are resolved at runtime by the Erlang VM
# On Linux, we need to link against the Erlang library
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
    LDFLAGS = -shared
    LDFLAGS += -undefined dynamic_lookup
else
    LDFLAGS = -shared
    LDFLAGS += -L$(ERL_EI_LIB_DIR)
    LDFLAGS += -lei
endif

# Source and output
CXX_SRC = c_src/aria_lbfgspp_nif.c
OUTPUT_DIR = priv/native
OUTPUT = $(OUTPUT_DIR)/libaria_lbfgspp.so

all: $(OUTPUT)

$(OUTPUT): $(CXX_SRC)
	@mkdir -p $(OUTPUT_DIR)
	$(CXX) $(CXXFLAGS) $(LDFLAGS) -o $(OUTPUT) $(CXX_SRC)

clean:
	rm -rf $(OUTPUT_DIR)
