# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaLbfgspp.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: AriaLbfgspp.Server.Registry},
      {Agent, fn -> %{} end, name: AriaLbfgspp.InstanceStore},
      AriaLbfgspp.Repo
    ]

    opts = [strategy: :one_for_one, name: AriaLbfgspp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
