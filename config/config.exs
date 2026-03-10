# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :aurum_finance,
  ecto_repos: [AurumFinance.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true]

config :aurum_finance, AurumFinance.Ingestion.LocalFileStorage,
  base_path: Path.expand("../tmp/imports", __DIR__)

config :aurum_finance, Oban,
  repo: AurumFinance.Repo,
  plugins: [
    {Oban.Plugins.Pruner, max_age: 60 * 60 * 24}
  ],
  queues: [
    imports: 5
  ]

# Configure the endpoint
config :aurum_finance, AurumFinanceWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: AurumFinanceWeb.ErrorHTML, json: AurumFinanceWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: AurumFinance.PubSub,
  live_view: [signing_salt: "AaUSsmHU"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  aurum_finance: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.12",
  aurum_finance: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
