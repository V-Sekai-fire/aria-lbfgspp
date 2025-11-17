# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaLbfgspp.Repo do
  use Ecto.Repo,
    otp_app: :aria_lbfgspp,
    adapter: Ecto.Adapters.SQLite3
end
