defmodule AurumFinance.Repo do
  use Ecto.Repo,
    otp_app: :aurum_finance,
    adapter: Ecto.Adapters.Postgres
end
