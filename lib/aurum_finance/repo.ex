defmodule AurumFinance.Repo do
  use Ecto.Repo,
    otp_app: :aurum_finance,
    adapter: Ecto.Adapters.Postgres

  use Scrivener, page_size: 20
end
