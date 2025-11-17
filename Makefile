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
CFLAGS = -fPIC -shared -O3 -Wall -Wextra
CFLAGS += -I$(ERL_EI_INCLUDE_DIR)
CFLAGS += -I$(LBFGSPP_INCLUDE_DIR)
CFLAGS += -I$(EIGEN_INCLUDE_DIR)
CFLAGS += -std=c11

# Source and output
C_SRC = c_src/aria_lbfgspp_nif.c
OUTPUT_DIR = priv/native
OUTPUT = $(OUTPUT_DIR)/libaria_lbfgspp.so

all: $(OUTPUT)

$(OUTPUT): $(C_SRC)
	@mkdir -p $(OUTPUT_DIR)
	$(CC) $(CFLAGS) -o $(OUTPUT) $(C_SRC) -L$(ERL_EI_LIB_DIR) -lei

clean:
	rm -rf $(OUTPUT_DIR)
