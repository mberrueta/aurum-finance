defmodule AurumFinanceWeb.AuthProtectionTest do
  use AurumFinanceWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  @protected_live_paths [
    "/",
    "/dashboard",
    "/accounts",
    "/transactions",
    "/import",
    "/rules",
    "/reconciliation",
    "/fx",
    "/reports",
    "/settings"
  ]

  test "all protected live routes redirect unauthenticated users", %{conn: conn} do
    for path <- @protected_live_paths do
      assert {:error, {:redirect, %{to: "/login"}}} = live(conn, path)
    end
  end

  test "protected live route expires when idle timeout exceeded", %{conn: conn} do
    conn = put_root_session_timestamps(conn, 1_700_000_000, 1_700_000_000)

    assert {:error, {:redirect, %{to: "/login"}}} = live(conn, "/dashboard")
  end

  test "protected live route remains valid at timeout boundary", %{conn: conn} do
    now = DateTime.utc_now() |> DateTime.to_unix(:second)
    boundary_last_seen = now - AurumFinance.Auth.idle_timeout_seconds()

    conn = put_root_session_timestamps(conn, boundary_last_seen, boundary_last_seen)

    assert {:ok, _view, _html} = live(conn, "/dashboard")
  end
end
