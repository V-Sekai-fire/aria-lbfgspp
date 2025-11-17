#!/usr/bin/env elixir

# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

# Simple optimization example using the CARBS-like interface
# Optimizes a simple quadratic function: f(x) = (x - 1.0)^2

Mix.install([
  {:aria_lbfgspp, path: Path.expand("../", __DIR__)}
])

# Ensure NIF is compiled
System.cmd("make", [], cd: Path.expand("../", __DIR__))

# Define parameter space
params = %{
  "epsilon" => 1.0e-6,
  "max_iterations" => 50,
  "m" => 6
}

param_spaces = [
  %{
    "name" => "x",
    "space_type" => "LinearSpace",
    "min" => -5.0,
    "max" => 5.0,
    "scale" => 1.0,
    "search_center" => 0.0
  }
]

# Initialize optimizer
case AriaLbfgspp.init(params, param_spaces) do
  {:ok, :lbfgspp_initialized} ->
    IO.puts("Optimizer initialized. Starting optimization...\n")

    # Optimization loop
    best_result =
      Enum.reduce(1..20, {1_000_000.0, nil}, fn iteration, {current_best, _} ->
        case AriaLbfgspp.suggest() do
          {:ok, suggestion} ->
            x = suggestion["x"]

            # Objective function: (x - 1.0)^2
            objective = :math.pow(x - 1.0, 2)
            cost = 1.0

            IO.puts("Iteration #{iteration}: x = #{:erlang.float_to_binary(x, decimals: 6)}, f(x) = #{:erlang.float_to_binary(objective, decimals: 6)}")

            case AriaLbfgspp.observe(suggestion, objective, cost, false) do
              {:ok, :observed} ->
                if objective < current_best do
                  {objective, suggestion}
                else
                  {current_best, nil}
                end

              {:error, reason} ->
                IO.puts("Error: #{reason}")
                {current_best, nil}
            end

          {:error, reason} ->
            IO.puts("Error getting suggestion: #{reason}")
            {current_best, nil}
        end
      end)

    {best_objective, best_suggestion} = best_result

    if best_suggestion != nil do
      x_value = best_suggestion["x"]
      IO.puts("\nOptimization complete!")
      IO.puts("Best x found: #{:erlang.float_to_binary(x_value, decimals: 6)}")
      IO.puts("Best objective: #{:erlang.float_to_binary(best_objective, decimals: 6)}")
      IO.puts("Expected optimal x: 1.0")
      IO.puts("Distance from optimal: #{:erlang.float_to_binary(abs(x_value - 1.0), decimals: 6)}")
    end

  {:error, reason} ->
    IO.puts("Failed to initialize optimizer: #{reason}")
end
