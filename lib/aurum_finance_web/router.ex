defmodule AurumFinanceWeb.Router do
  use AurumFinanceWeb, :router

  import Oban.Web.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {AurumFinanceWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :redirect_if_root_authenticated do
    plug AurumFinanceWeb.RootAuth, :redirect_if_root_authenticated
  end

  pipeline :require_authenticated_root do
    plug AurumFinanceWeb.RootAuth, :require_authenticated_root
  end

  scope "/", AurumFinanceWeb do
    pipe_through [:browser, :redirect_if_root_authenticated]

    get "/login", AuthController, :new
    post "/login", AuthController, :create
  end

  scope "/", AurumFinanceWeb do
    pipe_through [:browser, :require_authenticated_root]

    delete "/logout", AuthController, :delete

    live_session :app,
      on_mount: [{AurumFinanceWeb.RootAuth, :ensure_authenticated}],
      layout: {AurumFinanceWeb.Layouts, :app} do
      live "/", DashboardLive, :index
      live "/dashboard", DashboardLive, :index
      live "/entities", EntitiesLive, :index
      live "/accounts", AccountsLive, :index
      live "/transactions", TransactionsLive, :index
      live "/import", ImportLive, :index
      live "/import/accounts/:account_id/files/:imported_file_id", ImportDetailsLive, :show
      live "/rules", RulesLive, :index
      live "/reconciliation", ReconciliationLive, :index
      live "/fx", FxLive, :index
      live "/reports", ReportsLive, :index
      live "/settings", SettingsLive, :index
      live "/audit-log", AuditLogLive, :index
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", AurumFinanceWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard in development
  if Application.compile_env(:aurum_finance, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: AurumFinanceWeb.Telemetry
    end

    scope "/" do
      pipe_through :browser

      oban_dashboard("/oban")
    end
  end
end
