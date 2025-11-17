# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaLbfgspp.TestFixtures.ScenarioHelpers do
  @moduledoc """
  Helper functions for scenario testing with sample data and objective functions.
  """

  @doc """
  Evaluates neural network hyperparameters and returns validation loss.
  Uses a quadratic loss function with known optimal values.
  """
  def evaluate_neural_network_hyperparams(suggestion) do
    learning_rate = suggestion["learning_rate"]
    batch_size = suggestion["batch_size"]
    dropout_rate = suggestion["dropout_rate"]
    weight_decay = suggestion["weight_decay"]

    # Optimal values: lr=0.001, batch=64, dropout=0.5, weight_decay=1e-4
    optimal_lr = 0.001
    optimal_batch = 64.0
    optimal_dropout = 0.5
    optimal_wd = 1.0e-4

    # Quadratic loss function with known minimum
    validation_loss =
      :math.pow(learning_rate - optimal_lr, 2) * 100.0 +
        :math.pow(batch_size - optimal_batch, 2) * 0.01 +
        :math.pow(dropout_rate - optimal_dropout, 2) * 10.0 +
        :math.pow(weight_decay - optimal_wd, 2) * 1.0e8

    # Add some noise to simulate real training variance
    validation_loss + (:rand.uniform() - 0.5) * 0.1
  end

  @doc """
  Evaluates manufacturing process parameters and returns negative yield.
  Optimal conditions: temp=220°C, pressure=5.5 bar, flow=1.2 L/min, time=35 min
  """
  def evaluate_manufacturing_process(suggestion) do
    temperature = suggestion["temperature"]
    pressure = suggestion["pressure"]
    flow_rate = suggestion["flow_rate"]
    reaction_time = suggestion["reaction_time"]

    optimal_temp = 220.0
    optimal_pressure = 5.5
    optimal_flow = 1.2
    optimal_time = 35.0

    # Negative yield (we minimize this, so maximizing yield)
    negative_yield =
      :math.pow(temperature - optimal_temp, 2) * 0.01 +
        :math.pow(pressure - optimal_pressure, 2) * 0.1 +
        :math.pow(flow_rate - optimal_flow, 2) * 1.0 +
        :math.pow(reaction_time - optimal_time, 2) * 0.05

    # Add process noise
    negative_yield + (:rand.uniform() - 0.5) * 0.5
  end

  @doc """
  Evaluates inventory management parameters and returns total cost.
  Optimal: reorder_point=120, order_quantity=250, safety_stock=30, review_period=7
  """
  def evaluate_inventory_cost(suggestion) do
    reorder_point = suggestion["reorder_point"]
    order_quantity = suggestion["order_quantity"]
    safety_stock = suggestion["safety_stock"]
    review_period = suggestion["review_period"]

    optimal_reorder = 120.0
    optimal_quantity = 250.0
    optimal_safety = 30.0
    optimal_review = 7.0

    # Total cost function (holding + ordering + stockout)
    total_cost =
      :math.pow(reorder_point - optimal_reorder, 2) * 0.1 +
        :math.pow(order_quantity - optimal_quantity, 2) * 0.01 +
        :math.pow(safety_stock - optimal_safety, 2) * 0.5 +
        :math.pow(review_period - optimal_review, 2) * 2.0

    total_cost + (:rand.uniform() - 0.5) * 5.0
  end

  @doc """
  Returns typical cost/time for neural network training evaluation.
  """
  def neural_network_cost, do: 120.0

  @doc """
  Returns typical cost/time for manufacturing process evaluation.
  """
  def manufacturing_process_cost, do: 300.0

  @doc """
  Returns typical cost/time for inventory simulation.
  """
  def inventory_simulation_cost, do: 60.0

  @doc """
  Evaluates a Gaussian process-like function with known ground truth.
  Returns objective value with Gaussian noise.

  Ground truth optimal point is at x = [1.0, 2.0, 0.5] for 3D case.
  Function: f(x) = sum((x_i - optimal_i)^2) + noise
  """
  def evaluate_gaussian_process(suggestion, ground_truth, noise_std \\ 0.1) do
    # Extract parameter values in sorted order by key name
    param_values =
      suggestion
      |> Map.to_list()
      |> Enum.sort_by(fn {k, _v} -> k end)
      |> Enum.map(fn {_k, v} -> v end)

    # Calculate squared distance from ground truth
    squared_distance =
      param_values
      |> Enum.zip(ground_truth)
      |> Enum.map(fn {x, gt} -> :math.pow(x - gt, 2) end)
      |> Enum.sum()

    # Add Gaussian noise (using Box-Muller transform approximation)
    # Sum of 4 uniform randoms approximates normal distribution
    noise =
      (:rand.uniform() + :rand.uniform() + :rand.uniform() + :rand.uniform() - 2.0) * noise_std

    squared_distance + noise
  end

  @doc """
  Returns ground truth optimal point for Gaussian process test (3D).
  """
  def gaussian_process_ground_truth_3d, do: [1.0, 2.0, 0.5]

  @doc """
  Returns ground truth optimal point for Gaussian process test (2D).
  """
  def gaussian_process_ground_truth_2d, do: [0.5, 1.5]

  @doc """
  Returns typical cost/time for Gaussian process evaluation.
  """
  def gaussian_process_cost, do: 10.0
end
