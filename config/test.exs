import Config

# Keep runtime auth env check satisfied in test runs.
System.put_env(
  "AURUM_ROOT_PASSWORD_HASH",
  "$2b$12$0f4f9X6BlsQW2gD2qSiJ8el6x8xL5f0lIsvHF6f2L2hR8CT22zG0W"
)

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :aurum_finance, AurumFinance.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "aurum_finance_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :aurum_finance, AurumFinanceWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "aOsWc5zBn0/jQVnXpb7SvADdPxqj/wdw4FSmOvgxiq6z5mj3x5c4ikOJOdjyWIoE",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true

config :aurum_finance, AurumFinance.Ingestion.LocalFileStorage,
  base_path: Path.join(System.tmp_dir!(), "aurum_finance_test_imports")

config :aurum_finance, Oban,
  repo: AurumFinance.Repo,
  testing: :manual,
  plugins: false,
  queues: false
