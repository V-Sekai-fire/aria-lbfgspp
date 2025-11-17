# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

Mix.install([
  {:benchee, "~> 1.0"},
  {:aria_lbfgspp, path: Path.expand("../", __DIR__)}
])

# Ensure NIF is compiled
System.cmd("make", [], cd: Path.expand("../", __DIR__))

# Ensure application is started
Application.ensure_all_started(:aria_lbfgspp)

# Benchmark configuration
params = %{
  "epsilon" => 1.0e-6,
  "max_iterations" => 100,
  "m" => 6
}

param_spaces_2d = [
  %{"name" => "x1", "space_type" => "LinearSpace", "min" => -5.0, "max" => 5.0, "search_center" => 0.0},
  %{"name" => "x2", "space_type" => "LinearSpace", "min" => -5.0, "max" => 5.0, "search_center" => 0.0}
]

param_spaces_10d = Enum.map(1..10, fn i ->
  %{"name" => "x#{i}", "space_type" => "LinearSpace", "min" => -5.0, "max" => 5.0, "search_center" => 0.0}
end)

Benchee.run(
  %{
    "init (2D)" => fn ->
      case AriaLbfgspp.init(params, param_spaces_2d) do
        {:ok, _} -> :ok
        _ -> :error
      end
    end,
    "init (10D)" => fn ->
      case AriaLbfgspp.init(params, param_spaces_10d) do
        {:ok, _} -> :ok
        _ -> :error
      end
    end,
    "suggest (2D)" => fn ->
      case AriaLbfgspp.suggest() do
        {:ok, _} -> :ok
        _ -> :error
      end
    end,
    "observe (2D)" => fn ->
      suggestion = %{"x1" => 0.5, "x2" => 0.5}
      objective = 0.5
      cost = 1.0
      case AriaLbfgspp.observe(suggestion, objective, cost, false) do
        {:ok, _} -> :ok
        _ -> :error
      end
    end,
    "init_low_level (10D)" => fn ->
      case AriaLbfgspp.init_low_level(params, 10, List.duplicate(0.0, 10)) do
        {:ok, instance_id} ->
          AriaLbfgspp.stop(instance_id)
          :ok
        _ ->
          :error
      end
    end,
    "optimize_step (10D)" => fn ->
      {:ok, instance_id} = AriaLbfgspp.init_low_level(params, 10, List.duplicate(0.0, 10))
      objective = 1.0
      gradient = List.duplicate(0.1, 10)
      result = AriaLbfgspp.optimize_step(instance_id, objective, gradient)
      AriaLbfgspp.stop(instance_id)
      result
    end,
    "get_current_point" => fn ->
      {:ok, instance_id} = AriaLbfgspp.init_low_level(params, 10, List.duplicate(0.0, 10))
      result = AriaLbfgspp.get_current_point(instance_id)
      AriaLbfgspp.stop(instance_id)
      result
    end,
    "get_status" => fn ->
      {:ok, instance_id} = AriaLbfgspp.init_low_level(params, 10, List.duplicate(0.0, 10))
      result = AriaLbfgspp.get_status(instance_id)
      AriaLbfgspp.stop(instance_id)
      result
    end
  },
  time: 5,
  memory_time: 2,
  print: %{
    benchmarking: true,
    configuration: true,
    fast_warning: true
  }
)
