defmodule AurumFinance.MixProject do
  use Mix.Project

  def project do
    [
      app: :aurum_finance,
      version: "0.1.0",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        plt_add_apps: [:mix, :ex_unit],
        ignore_warnings: ".dialyzer_ignore.exs"
      ],
      listeners: [Phoenix.CodeReloader],
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.html": :test
      ]
    ]
  end

  def application do
    [
      mod: {AurumFinance.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  def cli do
    [
      preferred_envs: [
        precommit: :test,
        "precommit.full": :test
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:phoenix, "~> 1.8.4"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.13"},
      {:postgrex, ">= 0.0.0"},
      {:oban, "~> 2.20"},
      {:oban_web, "~> 2.11"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.1.0"},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.3", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.2.0",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 1.0"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.2.0"},
      {:bandit, "~> 1.5"},
      {:bcrypt_elixir, "~> 3.0"},

      # Development
      {:live_debugger, "~> 0.6.0", only: :dev},
      {:usage_rules, "~> 1.2", only: :dev},
      {:tidewave, "~> 0.4", only: :dev},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.8", only: [:dev, :test]},
      {:ex_doc, "~> 0.27", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:floki, ">= 0.30.0", only: :test},
      {:excoveralls, "~> 0.18.5", only: :test},
      {:mix_test_watch, "~> 1.0", only: [:dev, :test], runtime: false},
      {:faker, "~> 0.17", only: [:dev, :test]},
      {:ex_machina, "~> 2.8.0", only: [:dev, :test]},
      {:mock, "~> 0.3.0", only: :test},
      {:mox, "~> 1.0", only: :test},
      {:bypass, "~> 2.1", only: :test},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      tidewave:
        "run --no-halt -e 'Agent.start(fn -> Bandit.start_link(plug: Tidewave, port: String.to_integer(System.get_env(\"TIDEWAVE_PORT\") || \"4001\")) end)'",
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": [
        "ecto.create",
        "ecto.migrate",
        "run priv/repo/seeds.exs"
      ],
      "ecto.reset": [
        "ecto.drop",
        "ecto.setup"
      ],
      test: [
        "ecto.create --quiet",
        "ecto.migrate --quiet",
        "test"
      ],
      "assets.setup": [
        "tailwind.install --if-missing",
        "esbuild.install --if-missing"
      ],
      "assets.build": [
        "compile",
        "tailwind aurum_finance",
        "esbuild aurum_finance"
      ],
      "assets.deploy": [
        "tailwind aurum_finance --minify",
        "esbuild aurum_finance --minify",
        "phx.digest"
      ],

      # Fast checks (used constantly)
      precommit: [
        "format --check-formatted",
        "compile --warnings-as-errors",
        "dialyzer",
        "credo"
      ],
      # Full validation (before PR)
      "precommit.full": [
        "precommit",
        "deps.unlock --unused",
        "sobelow --config .sobelow-conf",
        "credo --strict",
        "deps.audit",
        "test",
        "docs"
      ]
    ]
  end
end
