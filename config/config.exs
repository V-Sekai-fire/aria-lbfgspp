import Config

# Ecto configuration for SQLite database
config :aria_lbfgspp,
  ecto_repos: [AriaLbfgspp.Repo]

config :aria_lbfgspp, AriaLbfgspp.Repo,
  database: Path.expand("../priv/aria_lbfgspp.db", __DIR__),
  pool_size: 1,
  show_sensitive_data_on_connection_error: true
