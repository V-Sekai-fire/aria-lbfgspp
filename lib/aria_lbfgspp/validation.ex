# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaLbfgspp.Validation do
  @moduledoc """
  Input validation helpers for aria-lbfgspp.

  This module provides validation functions for all public API inputs,
  ensuring type safety, range checks, and required field validation.
  """

  @doc """
  Validates LBFGS++ parameters map.

  Returns `:ok` if valid, `{:error, reason}` if invalid.
  """
  @spec validate_params(map()) :: :ok | {:error, String.t()}
  def validate_params(params) when not is_map(params) do
    {:error, "params must be a map"}
  end

  def validate_params(params) do
    cond do
      Map.has_key?(params, "epsilon") and not is_number(params["epsilon"]) ->
        {:error, "params[\"epsilon\"] must be a number"}

      Map.has_key?(params, "epsilon") and params["epsilon"] < 0 ->
        {:error, "params[\"epsilon\"] must be non-negative"}

      Map.has_key?(params, "max_iterations") and not is_integer(params["max_iterations"]) ->
        {:error, "params[\"max_iterations\"] must be an integer"}

      Map.has_key?(params, "max_iterations") and params["max_iterations"] <= 0 ->
        {:error, "params[\"max_iterations\"] must be positive"}

      Map.has_key?(params, "m") and not is_integer(params["m"]) ->
        {:error, "params[\"m\"] must be an integer"}

      Map.has_key?(params, "m") and params["m"] <= 0 ->
        {:error, "params[\"m\"] must be positive"}

      Map.has_key?(params, "m") and params["m"] > 100 ->
        {:error, "params[\"m\"] must be <= 100 (memory limit)"}

      Map.has_key?(params, "past") and not is_integer(params["past"]) ->
        {:error, "params[\"past\"] must be an integer"}

      Map.has_key?(params, "past") and params["past"] < 0 ->
        {:error, "params[\"past\"] must be non-negative"}

      Map.has_key?(params, "delta") and not is_number(params["delta"]) ->
        {:error, "params[\"delta\"] must be a number"}

      Map.has_key?(params, "delta") and params["delta"] < 0 ->
        {:error, "params[\"delta\"] must be non-negative"}

      Map.has_key?(params, "max_step") and not is_number(params["max_step"]) ->
        {:error, "params[\"max_step\"] must be a number"}

      Map.has_key?(params, "max_step") and params["max_step"] < 0 ->
        {:error, "params[\"max_step\"] must be non-negative"}

      Map.has_key?(params, "epsilon_rel") and not is_number(params["epsilon_rel"]) ->
        {:error, "params[\"epsilon_rel\"] must be a number"}

      Map.has_key?(params, "epsilon_rel") and params["epsilon_rel"] < 0 ->
        {:error, "params[\"epsilon_rel\"] must be non-negative"}

      true ->
        :ok
    end
  end

  @doc """
  Validates a parameter space definition.

  Returns `:ok` if valid, `{:error, reason}` if invalid.
  """
  @spec validate_param_space(map()) :: :ok | {:error, String.t()}
  def validate_param_space(space) when not is_map(space) do
    {:error, "param_space must be a map"}
  end

  def validate_param_space(space) do
    cond do
      not Map.has_key?(space, "name") ->
        {:error, "param_space must have \"name\" field"}

      not is_binary(space["name"]) ->
        {:error, "param_space[\"name\"] must be a string"}

      String.length(space["name"]) == 0 ->
        {:error, "param_space[\"name\"] cannot be empty"}

      not Map.has_key?(space, "space_type") ->
        {:error, "param_space must have \"space_type\" field"}

      space["space_type"] not in ["LinearSpace", "LogSpace", "LogitSpace"] ->
        {:error, "param_space[\"space_type\"] must be one of: LinearSpace, LogSpace, LogitSpace"}

      not Map.has_key?(space, "min") ->
        {:error, "param_space must have \"min\" field"}

      not is_number(space["min"]) ->
        {:error, "param_space[\"min\"] must be a number"}

      not Map.has_key?(space, "max") ->
        {:error, "param_space must have \"max\" field"}

      not is_number(space["max"]) ->
        {:error, "param_space[\"max\"] must be a number"}

      space["min"] >= space["max"] ->
        {:error, "param_space[\"min\"] must be < param_space[\"max\"]"}

      not Map.has_key?(space, "search_center") ->
        {:error, "param_space must have \"search_center\" field"}

      not is_number(space["search_center"]) ->
        {:error, "param_space[\"search_center\"] must be a number"}

      space["search_center"] < space["min"] or space["search_center"] > space["max"] ->
        {:error, "param_space[\"search_center\"] must be between min and max"}

      Map.has_key?(space, "scale") and not is_number(space["scale"]) ->
        {:error, "param_space[\"scale\"] must be a number if provided"}

      Map.has_key?(space, "scale") and space["scale"] <= 0 ->
        {:error, "param_space[\"scale\"] must be positive if provided"}

      Map.has_key?(space, "is_integer") and not is_boolean(space["is_integer"]) ->
        {:error, "param_space[\"is_integer\"] must be a boolean if provided"}

      true ->
        :ok
    end
  end

  @doc """
  Validates a list of parameter spaces.

  Returns `:ok` if valid, `{:error, reason}` if invalid.
  """
  @spec validate_param_spaces(list()) :: :ok | {:error, String.t()}
  def validate_param_spaces(spaces) when not is_list(spaces) do
    {:error, "param_spaces must be a list"}
  end

  def validate_param_spaces([]) do
    {:error, "param_spaces cannot be empty"}
  end

  def validate_param_spaces(spaces) do
    # Check for duplicate names
    names = Enum.map(spaces, &Map.get(&1, "name"))
    unique_names = Enum.uniq(names)

    if length(names) != length(unique_names) do
      duplicates = names -- unique_names
      {:error, "param_spaces contains duplicate names: #{inspect(Enum.uniq(duplicates))}"}
    else
      # Validate each space
      Enum.reduce_while(spaces, :ok, fn space, _acc ->
        case validate_param_space(space) do
          :ok -> {:cont, :ok}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)
    end
  end

  @doc """
  Validates dimension parameter.

  Returns `:ok` if valid, `{:error, reason}` if invalid.
  """
  @spec validate_dimension(integer()) :: :ok | {:error, String.t()}
  def validate_dimension(dimension) when not is_integer(dimension) do
    {:error, "dimension must be an integer"}
  end

  def validate_dimension(dimension) when dimension <= 0 do
    {:error, "dimension must be positive"}
  end

  def validate_dimension(dimension) when dimension > 10_000 do
    {:error, "dimension must be <= 10000 (safety limit)"}
  end

  def validate_dimension(_dimension), do: :ok

  @doc """
  Validates initial point list.

  Returns `:ok` if valid, `{:error, reason}` if invalid.
  """
  @spec validate_initial_point(list(), integer()) :: :ok | {:error, String.t()}
  def validate_initial_point(point, expected_dimension) when not is_list(point) do
    {:error, "initial_point must be a list"}
  end

  def validate_initial_point(point, expected_dimension) do
    cond do
      length(point) != expected_dimension ->
        {:error,
         "initial_point length (#{length(point)}) must match dimension (#{expected_dimension})"}

      not Enum.all?(point, &is_number/1) ->
        {:error, "initial_point must contain only numbers"}

      not Enum.all?(point, &(is_float(&1) or is_integer(&1))) ->
        {:error, "initial_point must contain only numeric values"}

      true ->
        :ok
    end
  end

  @doc """
  Validates gradient vector.

  Returns `:ok` if valid, `{:error, reason}` if invalid.
  """
  @spec validate_gradient(list(), integer()) :: :ok | {:error, String.t()}
  def validate_gradient(gradient, expected_dimension) when not is_list(gradient) do
    {:error, "gradient must be a list"}
  end

  def validate_gradient(gradient, expected_dimension) do
    cond do
      length(gradient) != expected_dimension ->
        {:error,
         "gradient length (#{length(gradient)}) must match dimension (#{expected_dimension})"}

      not Enum.all?(gradient, &is_number/1) ->
        {:error, "gradient must contain only numbers"}

      not Enum.all?(gradient, &(is_float(&1) or is_integer(&1))) ->
        {:error, "gradient must contain only numeric values"}

      true ->
        :ok
    end
  end

  @doc """
  Validates objective value.

  Returns `:ok` if valid, `{:error, reason}` if invalid.
  """
  @spec validate_objective_value(number()) :: :ok | {:error, String.t()}
  def validate_objective_value(value) when not is_number(value) do
    {:error, "objective_value must be a number"}
  end

  def validate_objective_value(value) when not (is_float(value) or is_integer(value)) do
    {:error, "objective_value must be a numeric value"}
  end

  def validate_objective_value(value) do
    # Check for NaN (NaN != NaN is true)
    # For infinity, we accept it as it's a valid float value in Elixir
    # Users can check for infinity themselves if needed
    if value != value do
      {:error, "objective_value must be finite (not NaN or Infinity)"}
    else
      :ok
    end
  end

  @doc """
  Validates cost value.

  Returns `:ok` if valid, `{:error, reason}` if invalid.
  """
  @spec validate_cost(number()) :: :ok | {:error, String.t()}
  def validate_cost(cost) when not is_number(cost) do
    {:error, "cost must be a number"}
  end

  def validate_cost(cost) when not (is_float(cost) or is_integer(cost)) do
    {:error, "cost must be a numeric value"}
  end

  def validate_cost(cost) when cost < 0 do
    {:error, "cost must be non-negative"}
  end

  def validate_cost(cost) do
    # Check for NaN (NaN != NaN is true)
    # For infinity, we accept it as it's a valid float value in Elixir
    # Users can check for infinity themselves if needed
    if cost != cost do
      {:error, "cost must be finite (not NaN or Infinity)"}
    else
      :ok
    end
  end
end
