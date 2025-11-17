# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaLbfgspp.TestFixtures.LbfgsppConfig do
  @moduledoc """
  Test fixtures for LBFGS++ configuration parameters.

  Provides common LBFGS++ configuration setups for testing.
  """

  @doc """
  Returns a minimal LBFGS++ configuration for testing.
  """
  def minimal_config do
    %{
      "epsilon" => 1.0e-6,
      "max_iterations" => 100,
      "m" => 6,
      "past" => 0,
      "delta" => 0.0,
      "max_step" => 0.0,
      "epsilon_rel" => 0.0
    }
  end

  @doc """
  Returns a default LBFGS++ configuration.
  """
  def default_config do
    %{
      "epsilon" => 1.0e-6,
      "max_iterations" => 200,
      "m" => 6,
      "past" => 0,
      "delta" => 0.0,
      "max_step" => 0.0,
      "epsilon_rel" => 0.0
    }
  end

  @doc """
  Returns a LBFGS++ configuration optimized for quick testing (fewer iterations).
  """
  def quick_test_config do
    %{
      "epsilon" => 1.0e-4,
      "max_iterations" => 50,
      "m" => 6,
      "past" => 0,
      "delta" => 0.0,
      "max_step" => 0.0,
      "epsilon_rel" => 0.0
    }
  end

  @doc """
  Returns a LBFGS++ configuration with stricter convergence criteria.
  """
  def strict_config do
    %{
      "epsilon" => 1.0e-8,
      "max_iterations" => 500,
      "m" => 10,
      "past" => 5,
      "delta" => 1.0e-8,
      "max_step" => 0.0,
      "epsilon_rel" => 1.0e-8
    }
  end

  @doc """
  Returns a LBFGS++ configuration optimized for scenario testing.
  Balanced between speed and accuracy.
  """
  def scenario_config do
    %{
      "epsilon" => 1.0e-5,
      "max_iterations" => 100,
      "m" => 6,
      "past" => 0,
      "delta" => 0.0,
      "max_step" => 1.0e20,
      "epsilon_rel" => 1.0e-5
    }
  end
end
