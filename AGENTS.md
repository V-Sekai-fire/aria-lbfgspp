# AriaLbfgspp

Elixir wrapper for LBFGS++ optimizer using NIFs and GenServer. Provides both CARBS-like gradient-free interface and low-level gradient-based interface.

## Build & Test

- Install dependencies: `mix deps.get`
- Build NIF: `make` (compiles C NIF to `priv/native/libaria_lbfgspp.so`)
- Compile Elixir: `mix compile`
- Run tests: `mix test`
- Type check: `mix dialyzer` (requires `mix dialyzer --plt`)
- Lint: `mix credo`

**Full build sequence:**

```bash
mix deps.get
make
mix compile
mix test
```

## Architecture Overview

- **`AriaLbfgspp`** - Main API module (CARBS-like `init/2`, `suggest/0`, `observe/4` and low-level `init_low_level/3`, `optimize_step/3`)
- **`AriaLbfgspp.Server`** - GenServer managing optimizer instances with observation history
- **`AriaLbfgspp.Native`** - NIF interface to C++ LBFGS++ (`c_src/aria_lbfgspp_nif.c`)
- **`AriaLbfgspp.InstanceStore`** - Agent storing instance registry (default instance for CARBS-like interface)
- **`AriaLbfgspp.Storage`** - Ecto schemas for optional persistence

**Process Model:**

- Each optimizer instance runs as a separate GenServer
- InstanceStore Agent maintains registry of active instances
- Observation history (last 10 entries) used for numerical gradient computation
- Native LBFGS++ handle managed per instance

## Conventions & Patterns

**Code Style:**

- Elixir ~> 1.18, standard formatting
- Module names: `AriaLbfgspp.*` for public API, `AriaLbfgspp.*` for internals
- Function naming: `init/2`, `suggest/0`, `observe/4` for CARBS-like; `init_low_level/3`, `optimize_step/3` for low-level
- Return tuples: `{:ok, result}` or `{:error, reason}`

**File Structure:**

- `lib/aria_lbfgspp.ex` - Main API
- `lib/aria_lbfgspp/` - Internal modules (Server, Native, Storage)
- `c_src/` - C NIF source
- `thirdparty/` - LBFGS++ and Eigen (git submodules or included)
- `test/fixtures/` - Test data (param spaces, configs)

**NIF Integration:**

- NIF must be compiled before use (`make`)
- Check availability with `AriaLbfgspp.available?/0` before operations
- NIF errors handled gracefully; fallback behavior when unavailable

**Instance Management:**

- CARBS-like interface uses "default" instance stored in InstanceStore Agent
- Low-level interface returns `instance_id` for explicit management
- Always call `AriaLbfgspp.stop/1` to clean up instances
- Multiple instances can run concurrently (each in separate GenServer)

## Testing Instructions

- Run all tests: `mix test`
- Tests use `ExUnit.Case`, `async: false` (NIF requires sequential execution)
- Test fixtures in `test/fixtures/` (param_spaces.exs, lbfgspp_config.exs)
- Industrial scenarios tested: neural network tuning, manufacturing, supply chain

**Test Structure:**

- `describe` blocks for each API function
- Setup ensures application started: `Application.ensure_all_started(:aria_lbfgspp)`
- Tests handle both success and NIF-unavailable cases

## Security

- No external API keys or credentials
- NIF loads native library; ensure `priv/native/` path is secure
- Instance state stored in-memory (GenServer); optional persistence via Ecto

## Git Workflows

- Branch from `main` with descriptive names: `feature/`, `bugfix/`
- Run `mix test` and `mix credo` before committing
- Keep commits atomic
- PRs should include: passing tests, no lint errors, clear description

## Gotchas

- **NIF compilation automatic**: `make` runs automatically via `elixir_make` compiler before `mix compile`
- **Observation history bounded**: Last 10 observations only (memory management)
- **Instance cleanup**: Always call `stop/1` to free native resources
- **Sequential tests**: Tests use `async: false` due to NIF constraints
- **Parameter spaces**: CARBS-like interface requires `param_spaces` list; low-level uses raw vectors
- **Gradient computation**: CARBS-like interface computes numerical gradients automatically from history
