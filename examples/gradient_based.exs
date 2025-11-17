#!/usr/bin/env elixir

# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

# Low-level gradient-based optimization example
# Optimizes f(x, y) = (x - 1.0)^2 + (y - 2.0)^2

Mix.install([
  {:aria_lbfgspp, path: Path.expand("../", __DIR__)}
])

# Ensure NIF is compiled
System.cmd("make", [], cd: Path.expand("../", __DIR__))

# Define parameters
params = %{
  "epsilon" => 1.0e-6,
  "max_iterations" => 50,
  "m" => 6
}

# Objective function and gradient
defmodule Objective do
  # f(x, y) = (x - 1.0)^2 + (y - 2.0)^2
  def evaluate([x, y]) do
    :math.pow(x - 1.0, 2) + :math.pow(y - 2.0, 2)
  end

  # Gradient: [2*(x - 1.0), 2*(y - 2.0)]
  def gradient([x, y]) do
    [2.0 * (x - 1.0), 2.0 * (y - 2.0)]
  end
end

# Initialize optimizer (2D problem, starting at origin)
case AriaLbfgspp.init_low_level(params, 2, [0.0, 0.0]) do
  {:ok, instance_id} ->
    IO.puts("Optimizer initialized. Instance ID: #{instance_id}\n")
    IO.puts("Optimizing f(x, y) = (x - 1.0)^2 + (y - 2.0)^2\n")

    # Optimization loop
    Enum.reduce(1..20, nil, fn iteration, _ ->
      # Get current point
      case AriaLbfgspp.get_current_point(instance_id) do
        {:ok, point} ->
          [x, y] = point

          # Evaluate objective and gradient
          objective = Objective.evaluate(point)
          gradient = Objective.gradient(point)

          IO.puts("Iteration #{iteration}:")
          IO.puts("  Point: [#{:erlang.float_to_binary(x, decimals: 6)}, #{:erlang.float_to_binary(y, decimals: 6)}]")
          IO.puts("  Objective: #{:erlang.float_to_binary(objective, decimals: 6)}")
          IO.puts("  Gradient norm: #{:erlang.float_to_binary(:math.sqrt(Enum.sum(Enum.map(gradient, fn g -> g * g end))), decimals: 6)}")

          # Perform optimization step
          case AriaLbfgspp.optimize_step(instance_id, objective, gradient) do
            {:ok, next_point} ->
              # Check status
              case AriaLbfgspp.get_status(instance_id) do
                {:ok, status} ->
                  if status.status == :converged do
                    IO.puts("\nConverged after #{status.iterations} iterations!")
                    throw(:converged)
                  end

                {:error, _} ->
                  :ok
              end

              next_point

            {:error, reason} ->
              IO.puts("Error in optimization step: #{reason}")
              throw(:error)
          end

        {:error, reason} ->
          IO.puts("Error getting current point: #{reason}")
          throw(:error)
      end
    end)

    # Final result
    case AriaLbfgspp.get_current_point(instance_id) do
      {:ok, [x, y]} ->
        objective = Objective.evaluate([x, y])
        IO.puts("\nFinal result:")
        IO.puts("  Point: [#{:erlang.float_to_binary(x, decimals: 6)}, #{:erlang.float_to_binary(y, decimals: 6)}]")
        IO.puts("  Objective: #{:erlang.float_to_binary(objective, decimals: 6)}")
        IO.puts("  Expected optimal: [1.0, 2.0]")
        IO.puts("  Distance: #{:erlang.float_to_binary(:math.sqrt(:math.pow(x - 1.0, 2) + :math.pow(y - 2.0, 2)), decimals: 6)}")
    end

    # Cleanup
    AriaLbfgspp.stop(instance_id)
    IO.puts("\nOptimizer stopped.")

  {:error, reason} ->
    IO.puts("Failed to initialize optimizer: #{reason}")
end
