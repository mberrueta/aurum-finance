defmodule AurumFinanceWeb.DashboardRouteTest do
  use AurumFinanceWeb.ConnCase
  import Phoenix.LiveViewTest

  test "GET / serves dashboard", %{conn: conn} do
    conn = log_in_root(conn)
    {:ok, _view, html} = live(conn, ~p"/")
    assert html =~ "Dashboard"
  end
end
