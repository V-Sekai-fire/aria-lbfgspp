#!/usr/bin/env elixir

# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

# Neural network hyperparameter optimization example
# Optimizes learning rate, batch size, dropout rate, and weight decay

Mix.install([
  {:aria_lbfgspp, path: Path.expand("../", __DIR__)}
])

# Ensure NIF is compiled
System.cmd("make", [], cd: Path.expand("../", __DIR__))

# Define parameter spaces for neural network hyperparameters
params = %{
  "epsilon" => 1.0e-6,
  "max_iterations" => 100,
  "m" => 6
}

param_spaces = [
  %{
    "name" => "learning_rate",
    "space_type" => "LogSpace",
    "min" => 0.0001,
    "max" => 0.1,
    "scale" => 1.0,
    "search_center" => 0.001
  },
  %{
    "name" => "batch_size",
    "space_type" => "LinearSpace",
    "min" => 16.0,
    "max" => 256.0,
    "scale" => 1.0,
    "search_center" => 64.0
  },
  %{
    "name" => "dropout_rate",
    "space_type" => "LinearSpace",
    "min" => 0.0,
    "max" => 0.8,
    "scale" => 1.0,
    "search_center" => 0.5
  },
  %{
    "name" => "weight_decay",
    "space_type" => "LogSpace",
    "min" => 1.0e-6,
    "max" => 1.0e-2,
    "scale" => 1.0,
    "search_center" => 1.0e-4
  }
]

# Simulated objective function (validation loss)
defmodule Objective do
  def evaluate(suggestion) do
    lr = suggestion["learning_rate"]
    batch = suggestion["batch_size"]
    dropout = suggestion["dropout_rate"]
    wd = suggestion["weight_decay"]

    # Optimal values (unknown in real scenario)
    optimal_lr = 0.001
    optimal_batch = 64.0
    optimal_dropout = 0.5
    optimal_wd = 1.0e-4

    # Quadratic loss with noise
    loss =
      :math.pow(lr - optimal_lr, 2) * 100.0 +
        :math.pow(batch - optimal_batch, 2) * 0.01 +
        :math.pow(dropout - optimal_dropout, 2) * 10.0 +
        :math.pow(wd - optimal_wd, 2) * 1.0e8

    loss + (:rand.uniform() - 0.5) * 0.1
  end
end

# Initialize optimizer
case AriaLbfgspp.init(params, param_spaces) do
  {:ok, :lbfgspp_initialized} ->
    IO.puts("Optimizer initialized. Starting hyperparameter optimization...\n")

    # Optimization loop
    best_result =
      Enum.reduce(1..30, {1_000_000.0, nil}, fn iteration, {current_best, _} ->
        case AriaLbfgspp.suggest() do
          {:ok, suggestion} ->
            # Evaluate hyperparameters (simulated training)
            validation_loss = Objective.evaluate(suggestion)
            cost = 120.0  # Simulated training time in seconds

            IO.puts("Iteration #{iteration}:")
            IO.puts("  lr=#{:erlang.float_to_binary(suggestion["learning_rate"], decimals: 6)}, " <>
                    "batch=#{suggestion["batch_size"]}, " <>
                    "dropout=#{:erlang.float_to_binary(suggestion["dropout_rate"], decimals: 3)}, " <>
                    "wd=#{:erlang.float_to_binary(suggestion["weight_decay"], decimals: 8)}")
            IO.puts("  Validation loss: #{:erlang.float_to_binary(validation_loss, decimals: 6)}")

            case AriaLbfgspp.observe(suggestion, validation_loss, cost, false) do
              {:ok, :observed} ->
                if validation_loss < current_best do
                  {validation_loss, suggestion}
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

    {best_loss, best_params} = best_result

    if best_params != nil do
      IO.puts("\nOptimization complete!")
      IO.puts("Best hyperparameters found:")
      IO.puts("  Learning rate: #{:erlang.float_to_binary(best_params["learning_rate"], decimals: 6)}")
      IO.puts("  Batch size: #{best_params["batch_size"]}")
      IO.puts("  Dropout rate: #{:erlang.float_to_binary(best_params["dropout_rate"], decimals: 3)}")
      IO.puts("  Weight decay: #{:erlang.float_to_binary(best_params["weight_decay"], decimals: 8)}")
      IO.puts("Best validation loss: #{:erlang.float_to_binary(best_loss, decimals: 6)}")
    end

  {:error, reason} ->
    IO.puts("Failed to initialize optimizer: #{reason}")
end
