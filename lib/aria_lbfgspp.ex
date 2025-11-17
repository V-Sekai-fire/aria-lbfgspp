# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaLbfgspp do
  @moduledoc """
  Elixir wrapper for LBFGS++ (Limited-memory BFGS) optimizer.

  This module provides Elixir functions to interact with LBFGS++ through NIFs.
  LBFGS++ is a gradient-based optimization algorithm for unconstrained and
  box-constrained minimization problems.

  This module provides both a CARBS-like high-level interface and a low-level
  gradient-based interface.
  """

  require Logger
  alias AriaLbfgspp.Server

  # Agent to store default instance (CARBS-like interface)
  @agent_name __MODULE__.InstanceStore

  defp ensure_agent do
    case Process.whereis(@agent_name) do
      nil ->
        case Agent.start_link(fn -> %{} end, name: @agent_name) do
          {:ok, pid} -> pid
          {:error, {:already_started, pid}} -> pid
          error -> raise "Failed to start Agent: #{inspect(error)}"
        end

      pid ->
        pid
    end
  end

  @doc """
  Check if LBFGS++ NIF is available.
  """
  @spec available?() :: boolean()
  def available? do
    case Code.ensure_loaded(AriaLbfgspp.Native) do
      {:module, _} -> AriaLbfgspp.Native.loaded?()
      _ -> false
    end
  end

  @doc """
  Initialize an LBFGS++ optimizer with the given parameters and parameter spaces.
  This is the CARBS-like high-level interface.

  ## Parameters

  - `params`: A map with LBFGS++ configuration parameters
  - `param_spaces`: A list of parameter space definitions

  ## Examples

      params = %{
        "epsilon" => 1.0e-6,
        "max_iterations" => 100,
        "m" => 6
      }

      param_spaces = [
        %{"name" => "Alpha", "space_type" => "LogSpace", "min" => 0.01, "max" => 0.1, "search_center" => 0.02},
        %{"name" => "ScaleFact", "space_type" => "LinearSpace", "min" => 0.5, "max" => 2.0, "search_center" => 1.0}
      ]

      {:ok, :lbfgspp_initialized} = AriaLbfgspp.init(params, param_spaces)
  """
  @spec init(map(), list()) :: {:ok, :lbfgspp_initialized} | {:error, String.t()}
  def init(params, param_spaces) when is_map(params) and is_list(param_spaces) do
    case available?() do
      true ->
        do_init(params, param_spaces)

      false ->
        {:error, "LBFGS++ NIF not available"}
    end
  end

  @doc """
  Initialize an LBFGS++ optimizer with the given parameters (low-level interface).

  ## Parameters

  - `params`: A map with LBFGS++ configuration parameters
  - `dimension`: The dimension of the optimization problem
  - `initial_point`: Initial guess (optional, defaults to zeros)

  ## Examples

      params = %{
        "epsilon" => 1.0e-6,
        "max_iterations" => 100,
        "m" => 6
      }

      {:ok, instance_id} = AriaLbfgspp.init_low_level(params, 10)
  """
  @spec init_low_level(map(), integer(), list() | nil) :: {:ok, String.t()} | {:error, String.t()}
  def init_low_level(params, dimension, initial_point \\ nil)
      when is_map(params) and is_integer(dimension) and dimension > 0 do
    case available?() do
      true ->
        instance_id = generate_instance_id()
        initial_vec = initial_point || List.duplicate(0.0, dimension)

        case Server.start_link(instance_id, params, dimension, initial_vec, nil) do
          {:ok, _pid} ->
            {:ok, instance_id}

          {:error, {:already_started, _pid}} ->
            {:error, "Instance #{instance_id} already exists"}

          error ->
            {:error, "Failed to start optimizer: #{inspect(error)}"}
        end

      false ->
        {:error, "LBFGS++ NIF not available"}
    end
  end

  defp do_init(params, param_spaces) do
    ensure_agent()

    # Extract dimension from param_spaces
    dimension = length(param_spaces)

    if dimension == 0 do
      {:error, "param_spaces cannot be empty"}
    else
      # Extract initial point from search_center values
      initial_point =
        Enum.map(param_spaces, fn space ->
          Map.get(space, "search_center", 0.0)
        end)

      instance_id = "default"

      case Server.start_link(instance_id, params, dimension, initial_point, param_spaces) do
        {:ok, _pid} ->
          # Store instance in agent
          Agent.update(@agent_name, fn state ->
            Map.put(state, "default", instance_id)
          end)

          {:ok, :lbfgspp_initialized}

        {:error, {:already_started, _pid}} ->
          # Instance already exists, update it
          {:ok, :lbfgspp_initialized}

        error ->
          {:error, "Failed to start optimizer: #{inspect(error)}"}
      end
    end
  end

  @doc """
  Get a suggestion from LBFGS++ (CARBS-like interface).

  This should be called after initialization. The suggestion contains
  parameter values to test as a map with parameter names as keys.
  """
  @spec suggest() :: {:ok, map()} | {:error, String.t()}
  def suggest do
    ensure_agent()
    stored_instance = Agent.get(@agent_name, fn state -> Map.get(state, "default") end)

    case stored_instance do
      nil ->
        {:error, "LBFGS++ not initialized. Call init/2 first."}

      instance_id ->
        case Server.get_current_point(instance_id) do
          {:ok, point_vec} ->
            # Convert vector to map using param_spaces
            case Server.get_param_spaces(instance_id) do
              {:ok, param_spaces} ->
                suggestion_map = vector_to_map(point_vec, param_spaces)
                {:ok, suggestion_map}

              {:error, reason} ->
                {:error, reason}
            end

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  @doc """
  Observe a result from testing an LBFGS++ suggestion (CARBS-like interface).

  ## Parameters

  - `input`: The parameter values that were tested (from suggest/0)
  - `output`: The result/score from testing those parameters
  - `cost`: The cost (e.g., runtime in seconds) of the test
  - `is_failure`: Whether the test failed (default: false)

  If gradient is not provided, numerical gradient will be computed.
  """
  @spec observe(map(), float(), float(), boolean()) :: {:ok, :observed} | {:error, String.t()}
  def observe(input, output, cost, is_failure \\ false)
      when is_map(input) and is_float(output) and is_float(cost) and is_boolean(is_failure) do
    ensure_agent()
    stored_instance = Agent.get(@agent_name, fn state -> Map.get(state, "default") end)

    case stored_instance do
      nil ->
        {:error, "LBFGS++ not initialized. Call init/2 first."}

      instance_id ->
        case Server.get_param_spaces(instance_id) do
          {:ok, param_spaces} ->
            # Convert input map to vector
            input_vec = map_to_vector(input, param_spaces)

            # Get current point for gradient computation
            case Server.get_current_point(instance_id) do
              {:ok, current_point} ->
                # Store this observation for gradient computation
                Server.add_observation(instance_id, input_vec, output)

                # Compute numerical gradient using stored observations
                gradient =
                  compute_numerical_gradient(instance_id, input_vec, output, param_spaces)

                # Perform optimization step
                case Server.optimize_step(instance_id, output, gradient) do
                  {:ok, _next_point} ->
                    {:ok, :observed}

                  {:error, reason} ->
                    {:error, reason}
                end

              {:error, reason} ->
                {:error, reason}
            end

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  @doc """
  Run optimization step. This evaluates the objective function and gradient,
  then updates the optimizer state (low-level interface).

  ## Parameters

  - `instance_id`: The instance identifier returned from init_low_level/3
  - `objective_value`: The objective function value at current point
  - `gradient`: The gradient vector at current point

  Returns the next point to evaluate.
  """
  @spec optimize_step(String.t(), float(), list()) ::
          {:ok, list()} | {:error, String.t()}
  def optimize_step(instance_id, objective_value, gradient)
      when is_binary(instance_id) and is_float(objective_value) and is_list(gradient) do
    case Server.optimize_step(instance_id, objective_value, gradient) do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Get the current best point found by the optimizer.
  """
  @spec get_current_point(String.t()) :: {:ok, list()} | {:error, String.t()}
  def get_current_point(instance_id) when is_binary(instance_id) do
    case Server.get_current_point(instance_id) do
      {:ok, point} -> {:ok, point}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Get optimization status (iterations, gradient norm, etc.).
  """
  @spec get_status(String.t()) :: {:ok, map()} | {:error, String.t()}
  def get_status(instance_id) when is_binary(instance_id) do
    case Server.get_status(instance_id) do
      {:ok, status} -> {:ok, status}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Stop and cleanup an optimizer instance.
  """
  @spec stop(String.t()) :: :ok | {:error, String.t()}
  def stop(instance_id) when is_binary(instance_id) do
    case Server.stop(instance_id) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  # Helper functions for CARBS-like interface

  defp vector_to_map(vector, param_spaces) do
    param_spaces
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {space, idx}, acc ->
      param_name = Map.get(space, "name", "param_#{idx}")
      value = Enum.at(vector, idx)
      Map.put(acc, param_name, value)
    end)
  end

  defp map_to_vector(map, param_spaces) do
    Enum.map(param_spaces, fn space ->
      param_name = Map.get(space, "name")
      Map.get(map, param_name, Map.get(space, "search_center", 0.0))
    end)
  end

  defp compute_numerical_gradient(instance_id, current_point, objective_value, _param_spaces) do
    dimension = length(current_point)

    # Get observation history
    case Server.get_observation_history(instance_id) do
      {:ok, history} when length(history) >= 2 ->
        # Use finite differences with previous observations
        compute_gradient_from_history(current_point, objective_value, history, dimension)

      _ ->
        # Not enough observations yet - use a simple gradient estimate
        # based on the assumption that we want to minimize
        # Use a small random perturbation to break symmetry
        compute_initial_gradient_estimate(current_point, objective_value, dimension)
    end
  end

  defp compute_gradient_from_history(current_point, current_value, history, dimension) do
    # Find the most recent previous observation
    # Use finite differences: grad_i ≈ (f(x + h*e_i) - f(x)) / h
    # where h is the step size and e_i is the unit vector in direction i

    # Get the most recent different point (if available)
    previous_obs = Enum.find(history, fn {point, _value} -> point != current_point end)

    case previous_obs do
      {prev_point, prev_value} ->
        # Compute gradient using finite differences
        # grad ≈ (f(current) - f(previous)) / ||current - previous|| * direction
        delta_x = Enum.zip(current_point, prev_point) |> Enum.map(fn {a, b} -> a - b end)
        delta_f = current_value - prev_value

        # Avoid division by zero
        norm_sq = Enum.reduce(delta_x, 0.0, fn dx, acc -> acc + dx * dx end)

        if norm_sq > 1.0e-10 do
          # Gradient estimate: scale the direction vector by the function difference
          scale = delta_f / norm_sq
          Enum.map(delta_x, fn dx -> scale * dx end)
        else
          # Points are too close, use a small random gradient
          compute_initial_gradient_estimate(current_point, current_value, dimension)
        end

      nil ->
        # No previous observation found, use initial estimate
        compute_initial_gradient_estimate(current_point, current_value, dimension)
    end
  end

  defp compute_initial_gradient_estimate(current_point, objective_value, dimension) do
    # For the first few iterations, use a simple gradient estimate
    # Based on the objective value and a small perturbation direction
    # This helps LBFGS++ start moving even without gradient information

    # Use a small random direction scaled by the objective value
    # This encourages exploration while respecting the objective magnitude
    base_scale = if objective_value > 0, do: -0.01, else: 0.01

    Enum.map(1..dimension, fn i ->
      # Small random component for each dimension
      # This breaks symmetry and helps with initial exploration
      :rand.uniform() * base_scale * abs(objective_value)
    end)
  end

  defp generate_instance_id do
    :crypto.strong_rand_bytes(16)
    |> Base.encode16(case: :lower)
  end
end
