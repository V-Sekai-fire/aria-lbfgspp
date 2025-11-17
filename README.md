# AriaLbfgspp

Elixir wrapper for LBFGS++ (Limited-memory BFGS) optimizer using NIFs and GenServer.

## Overview

This library provides an Elixir interface to the LBFGS++ C++ optimization library. It offers both:

- **CARBS-like high-level interface** for gradient-free optimization
- **Low-level gradient-based interface** for explicit gradient optimization

It uses:

- **GenServer** for managing optimizer instances
- **NIFs** (Native Implemented Functions) for C++ integration
- **Ecto** for persistence
- **Numerical gradient computation** for gradient-free scenarios

## Installation

### As a dependency

Add to your `mix.exs`:

```elixir
def deps do
  [
    {:aria_lbfgspp, path: "path/to/aria_lbfgspp"}
  ]
end
```

### Standalone

```bash
cd aria_lbfgspp
mix deps.get
make
mix compile
```

## Building

The NIF requires compilation:

```bash
make
mix compile
```

## Usage

### CARBS-like Interface (Gradient-Free)

```elixir
# Initialize with parameter spaces
params = %{
  "epsilon" => 1e-6,
  "max_iterations" => 100,
  "m" => 6
}

param_spaces = [
  %{"name" => "learning_rate", "space_type" => "LogSpace", "min" => 0.0001, "max" => 0.1, "search_center" => 0.001},
  %{"name" => "batch_size", "space_type" => "LinearSpace", "min" => 16, "max" => 256, "search_center" => 64}
]

{:ok, :lbfgspp_initialized} = AriaLbfgspp.init(params, param_spaces)

# Optimization loop
{:ok, suggestion} = AriaLbfgspp.suggest()  # Returns map with parameter names

# Evaluate objective function (no gradient needed!)
objective_value = evaluate_function(suggestion)
cost = 120.0  # Time taken

# Observe result (gradient computed automatically)
{:ok, :observed} = AriaLbfgspp.observe(suggestion, objective_value, cost, false)
```

### Low-Level Interface (With Gradients)

```elixir
# Initialize with explicit dimension
params = %{
  "epsilon" => 1e-6,
  "max_iterations" => 100,
  "m" => 6
}

{:ok, instance_id} = AriaLbfgspp.init_low_level(params, 10, [0.0, 0.0, ...])

# Optimization loop
{:ok, point} = AriaLbfgspp.get_current_point(instance_id)

# Evaluate objective function and gradient
objective_value = compute_objective(point)
gradient = compute_gradient(point)

# Perform optimization step
{:ok, next_point} = AriaLbfgspp.optimize_step(instance_id, objective_value, gradient)

# Check status
{:ok, status} = AriaLbfgspp.get_status(instance_id)
IO.inspect(status.iterations)
IO.inspect(status.gradient_norm)

# Cleanup
AriaLbfgspp.stop(instance_id)
```

## Features

- **Dual Interface**: CARBS-like high-level API and low-level gradient API
- **Automatic Gradient Estimation**: Numerical gradients computed from observation history
- **Parameter Space Support**: LinearSpace, LogSpace, LogitSpace
- **Production Ready**: Handles edge cases, bounded memory, error recovery

## Architecture

- `AriaLbfgspp` - Main API module (CARBS-like and low-level interfaces)
- `AriaLbfgspp.Server` - GenServer for instance management
- `AriaLbfgspp.Native` - NIF interface to C++ LBFGS++
- `AriaLbfgspp.Storage` - Ecto schemas for persistence

See [AGENTS.md](AGENTS.md) for detailed information about the agent-based architecture.

## Testing

```bash
mix test
```

Includes industrial scenario tests:

- Neural network hyperparameter optimization
- Manufacturing process optimization
- Supply chain inventory optimization

## Requirements

- Elixir ~> 1.18
- C compiler (gcc/clang)
- Erlang/OTP with NIF support
- Eigen and LBFGS++ (included in `thirdparty/`)

## License

MIT

## Copyright

Copyright (c) 2025-present K. S. Ernest (iFire) Lee
