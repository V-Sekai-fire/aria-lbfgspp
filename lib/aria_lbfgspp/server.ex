# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaLbfgspp.Server do
  @moduledoc """
  GenServer for managing LBFGS++ optimizer instances.
  """

  use GenServer

  require Logger

  @registry_name __MODULE__.Registry

  # Server state
  defstruct [
    :instance_id,
    :params,
    :dimension,
    :current_point,
    :param_spaces,
    :native_handle,
    :iterations,
    :gradient_norm,
    :objective_value,
    :status,
    :observation_history
  ]

  # Client API

  def start_link(instance_id, params, dimension, initial_point, param_spaces \\ nil) do
    state = %__MODULE__{
      instance_id: instance_id,
      params: params,
      dimension: dimension,
      current_point: initial_point,
      param_spaces: param_spaces,
      iterations: 0,
      gradient_norm: 0.0,
      objective_value: 0.0,
      status: :idle,
      observation_history: []
    }

    GenServer.start_link(__MODULE__, state, name: via_tuple(instance_id))
  end

  def add_observation(instance_id, point, value) do
    GenServer.call(via_tuple(instance_id), {:add_observation, point, value})
  end

  def get_observation_history(instance_id) do
    GenServer.call(via_tuple(instance_id), :get_observation_history)
  end

  def optimize_step(instance_id, objective_value, gradient) do
    GenServer.call(via_tuple(instance_id), {:optimize_step, objective_value, gradient})
  end

  def get_current_point(instance_id) do
    GenServer.call(via_tuple(instance_id), :get_current_point)
  end

  def get_status(instance_id) do
    GenServer.call(via_tuple(instance_id), :get_status)
  end

  def get_param_spaces(instance_id) do
    GenServer.call(via_tuple(instance_id), :get_param_spaces)
  end

  def stop(instance_id) do
    case GenServer.whereis(via_tuple(instance_id)) do
      nil -> {:error, "Instance not found"}
      pid -> GenServer.stop(pid)
    end
  end

  defp via_tuple(instance_id) do
    {:via, Registry, {@registry_name, instance_id}}
  end

  # GenServer callbacks

  @impl true
  def init(state) do
    # Register the process
    Registry.register(@registry_name, state.instance_id, nil)

    # Initialize native LBFGS++ instance
    case initialize_native(state) do
      {:ok, native_handle, updated_state} ->
        {:ok, %{updated_state | native_handle: native_handle, status: :ready},
         {:continue, :ready}}

      {:error, reason} ->
        Logger.error("Failed to initialize LBFGS++: #{inspect(reason)}")
        {:ok, %{state | status: :error}, {:continue, :error}}
    end
  end

  @impl true
  def handle_continue(:ready, state) do
    {:noreply, state}
  end

  @impl true
  def handle_continue(:error, state) do
    {:noreply, state}
  end

  @impl true
  def handle_call({:optimize_step, objective_value, gradient}, _from, state) do
    case state.status do
      :ready ->
        case optimize_native(state, objective_value, gradient) do
          {:ok, next_point, updated_state} ->
            {:reply, {:ok, next_point}, updated_state}

          {:error, reason} ->
            {:reply, {:error, reason}, %{state | status: :error}}
        end

      :converged ->
        {:reply, {:ok, state.current_point}, state}

      _ ->
        {:reply, {:error, "Optimizer not ready"}, state}
    end
  end

  @impl true
  def handle_call(:get_current_point, _from, state) do
    {:reply, {:ok, state.current_point}, state}
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    status_map = %{
      instance_id: state.instance_id,
      status: state.status,
      iterations: state.iterations,
      gradient_norm: state.gradient_norm,
      objective_value: state.objective_value,
      dimension: state.dimension
    }

    {:reply, {:ok, status_map}, state}
  end

  @impl true
  def handle_call(:get_param_spaces, _from, state) do
    case state.param_spaces do
      nil -> {:reply, {:error, "No param_spaces stored for this instance"}, state}
      param_spaces -> {:reply, {:ok, param_spaces}, state}
    end
  end

  @impl true
  def handle_call({:add_observation, point, value}, _from, state) do
    # Store observation, keeping only recent ones (last 10)
    updated_history = [{point, value} | state.observation_history] |> Enum.take(10)
    updated_state = %{state | observation_history: updated_history}
    {:reply, :ok, updated_state}
  end

  @impl true
  def handle_call(:get_observation_history, _from, state) do
    {:reply, {:ok, state.observation_history}, state}
  end

  @impl true
  def handle_info(:cleanup, state) do
    cleanup_native(state)
    {:stop, :normal, state}
  end

  @impl true
  def terminate(_reason, state) do
    cleanup_native(state)
    :ok
  end

  # Native LBFGS++ integration

  defp initialize_native(state) do
    try do
      # Convert params to native format
      epsilon = Map.get(state.params, "epsilon", 1.0e-6)
      max_iterations = Map.get(state.params, "max_iterations", 100)
      m = Map.get(state.params, "m", 6)
      past = Map.get(state.params, "past", 0)
      delta = Map.get(state.params, "delta", 0.0)
      max_step = Map.get(state.params, "max_step", 0.0)
      epsilon_rel = Map.get(state.params, "epsilon_rel", 0.0)

      # Initialize native LBFGS++ instance
      case AriaLbfgspp.Native.init(
             state.dimension,
             epsilon,
             max_iterations,
             m,
             past,
             delta,
             max_step,
             epsilon_rel
           ) do
        {:ok, handle} ->
          # Set initial point
          case AriaLbfgspp.Native.set_initial_point(handle, state.current_point) do
            :ok ->
              updated_state = %{state | status: :ready}
              {:ok, handle, updated_state}

            {:error, reason} ->
              {:error, reason}
          end

        {:error, reason} ->
          {:error, reason}
      end
    rescue
      e -> {:error, Exception.message(e)}
    end
  end

  defp optimize_native(state, objective_value, gradient) do
    try do
      case AriaLbfgspp.Native.optimize_step(
             state.native_handle,
             state.current_point,
             objective_value,
             gradient
           ) do
        {:ok, next_point, iterations, grad_norm} ->
          updated_state = %{
            state
            | current_point: next_point,
              objective_value: objective_value,
              iterations: iterations,
              gradient_norm: grad_norm,
              status: if(grad_norm < state.params["epsilon"], do: :converged, else: :optimizing)
          }

          {:ok, next_point, updated_state}

        {:error, reason} ->
          {:error, reason}
      end
    rescue
      e -> {:error, Exception.message(e)}
    end
  end

  defp cleanup_native(state) do
    if state.native_handle do
      try do
        AriaLbfgspp.Native.cleanup(state.native_handle)
      rescue
        _ -> :ok
      end
    end

    :ok
  end
end
