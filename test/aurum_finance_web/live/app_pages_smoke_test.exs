defmodule AurumFinanceWeb.AppPagesSmokeTest do
  use AurumFinanceWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  test "dashboard page smoke", %{conn: conn} do
    conn = log_in_root(conn)
    {:ok, view, _html} = live(conn, "/dashboard")
    assert has_element?(view, "#dashboard-page")
    assert has_element?(view, "#app-shell-search")
    assert has_element?(view, "#logout-link")
  end

  test "accounts page smoke", %{conn: conn} do
    conn = log_in_root(conn)
    {:ok, view, _html} = live(conn, "/accounts")
    assert has_element?(view, "#accounts-page")
    assert has_element?(view, "#app-shell-search")
  end

  test "transactions page smoke", %{conn: conn} do
    conn = log_in_root(conn)
    {:ok, view, _html} = live(conn, "/transactions")
    assert has_element?(view, "#transactions-page")
    assert has_element?(view, "#app-shell-search")
  end

  test "import page smoke", %{conn: conn} do
    conn = log_in_root(conn)
    {:ok, view, _html} = live(conn, "/import")
    assert has_element?(view, "#import-page")
    assert has_element?(view, "#app-shell-search")
  end

  test "rules page smoke", %{conn: conn} do
    conn = log_in_root(conn)
    {:ok, view, _html} = live(conn, "/rules")
    assert has_element?(view, "#rules-page")
    assert has_element?(view, "#app-shell-search")
  end

  test "reconciliation page smoke", %{conn: conn} do
    conn = log_in_root(conn)
    {:ok, view, _html} = live(conn, "/reconciliation")
    assert has_element?(view, "#reconciliation-page")
    assert has_element?(view, "#app-shell-search")
  end

  test "fx page smoke", %{conn: conn} do
    conn = log_in_root(conn)
    {:ok, view, _html} = live(conn, "/fx")
    assert has_element?(view, "#fx-page")
    assert has_element?(view, "#app-shell-search")
  end

  test "reports page smoke", %{conn: conn} do
    conn = log_in_root(conn)
    {:ok, view, _html} = live(conn, "/reports")
    assert has_element?(view, "#reports-page")
    assert has_element?(view, "#app-shell-search")
  end

  test "settings page smoke", %{conn: conn} do
    conn = log_in_root(conn)
    {:ok, view, _html} = live(conn, "/settings")
    assert has_element?(view, "#settings-page")
    assert has_element?(view, "#app-shell-search")
  end
end
