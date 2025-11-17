# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaLbfgspp.Native do
  @moduledoc """
  NIF module for interfacing with LBFGS++ C++ library.
  """

  @on_load :load_nif

  def load_nif do
    # Load from priv/native relative to the application
    nif_path = Application.app_dir(:aria_lbfgspp, "priv/native/libaria_lbfgspp")

    case :erlang.load_nif(String.to_charlist(nif_path), 0) do
      :ok ->
        :ok

      {:error, {:load_failed, reason}} ->
        raise """
        Failed to load NIF library: #{inspect(reason)}

        Expected path: #{nif_path}.so

        Please ensure:
        1. NIF is compiled: run 'make' in the project root
        2. NIF exists at: #{nif_path}.so
        """

      {:error, reason} ->
        raise "Failed to load NIF library: #{inspect(reason)}"
    end
  end

  @doc """
  Check if NIF is loaded.
  """
  def loaded? do
    try do
      test_nif()
      true
    rescue
      _ -> false
    end
  end

  def test_nif do
    # This will be replaced by the NIF when loaded
    :erlang.nif_error(:nif_not_loaded)
  end

  @doc """
  Initialize LBFGS++ optimizer.

  Returns {:ok, handle} or {:error, reason}
  """
  def init(dimension, epsilon, max_iterations, m, past, delta, max_step, epsilon_rel) do
    init_nif(dimension, epsilon, max_iterations, m, past, delta, max_step, epsilon_rel)
  end

  @doc """
  Set initial point for optimization.
  """
  def set_initial_point(handle, initial_point) do
    set_initial_point_nif(handle, initial_point)
  end

  @doc """
  Perform one optimization step.

  Returns {:ok, next_point, iterations, gradient_norm} or {:error, reason}
  """
  def optimize_step(handle, _current_point, objective_value, gradient) do
    optimize_step_nif(handle, objective_value, gradient)
  end

  @doc """
  Cleanup native resources.
  """
  def cleanup(handle) do
    cleanup_nif(handle)
  end

  # NIF function stubs (will be replaced by C NIFs when loaded)
  def init_nif(_dimension, _epsilon, _max_iterations, _m, _past, _delta, _max_step, _epsilon_rel),
    do: :erlang.nif_error(:nif_not_loaded)

  def set_initial_point_nif(_handle, _initial_point), do: :erlang.nif_error(:nif_not_loaded)

  def optimize_step_nif(_handle, _objective_value, _gradient),
    do: :erlang.nif_error(:nif_not_loaded)

  def cleanup_nif(_handle), do: :erlang.nif_error(:nif_not_loaded)
end
