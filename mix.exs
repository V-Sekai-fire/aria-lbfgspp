# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaLbfgspp.MixProject do
  use Mix.Project

  def project do
    [
      app: :aria_lbfgspp,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      compilers: [:elixir_make] ++ Mix.compilers(),
      make_targets: ["all"],
      make_clean: ["clean"],
      deps: deps(),
      description: "Elixir wrapper for LBFGS++ (Limited-memory BFGS) optimizer using NIFs",
      package: package()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {AriaLbfgspp.Application, []}
    ]
  end

  defp deps do
    [
      {:elixir_make, "~> 0.7", runtime: false},
      {:jason, "~> 1.4"},
      {:ecto_sqlite3, "~> 0.22.0"},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    [
      maintainers: ["K. S. Ernest (iFire) Lee"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/V-Sekai-fire/aria-carbs"}
    ]
  end
end
