defmodule AurumFinanceWeb.AuthControllerTest do
  use AurumFinanceWeb.ConnCase

  import Phoenix.LiveViewTest

  setup do
    previous_hash = Application.get_env(:aurum_finance, :root_password_hash)
    hash = Bcrypt.hash_pwd_salt("test-root-password")
    Application.put_env(:aurum_finance, :root_password_hash, hash)
    :ok = AurumFinanceWeb.AuthRateLimiter.reset!()

    on_exit(fn ->
      if previous_hash do
        Application.put_env(:aurum_finance, :root_password_hash, previous_hash)
      else
        Application.delete_env(:aurum_finance, :root_password_hash)
      end

      :ok = AurumFinanceWeb.AuthRateLimiter.reset!()
    end)

    :ok
  end

  test "GET /login renders login page", %{conn: conn} do
    conn = get(conn, "/login")

    assert html_response(conn, 200) =~ "login-form"
  end

  test "GET /login shows setup message when root hash is missing", %{conn: conn} do
    Application.delete_env(:aurum_finance, :root_password_hash)

    conn = get(conn, "/login")
    html = html_response(conn, 200)

    assert html =~ "missing-root-password-hash"
    assert html =~ "AURUM_ROOT_PASSWORD_HASH is missing"
    refute html =~ "login-submit"
  end

  test "GET /login redirects when already authenticated", %{conn: conn} do
    conn =
      conn
      |> log_in_root()
      |> get("/login")

    assert redirected_to(conn) == "/"
  end

  test "POST /login authenticates, redirects, and sets session cookie", %{conn: conn} do
    conn = post(conn, "/login", %{"auth" => %{"password" => "test-root-password"}})

    assert redirected_to(conn) == "/"
    assert conn.resp_cookies["_aurum_finance_key"]
  end

  test "POST /login with invalid password re-renders page", %{conn: conn} do
    conn = post(conn, "/login", %{"auth" => %{"password" => "invalid"}})

    html = html_response(conn, 200)
    assert html =~ "login-form"
    assert html =~ "Invalid password"
  end

  test "POST /login throttles repeated invalid attempts", %{conn: conn} do
    conn =
      Enum.reduce(1..6, conn, fn _, acc_conn ->
        acc_conn
        |> Phoenix.ConnTest.recycle()
        |> post("/login", %{"auth" => %{"password" => "invalid"}})
      end)

    html = html_response(conn, 200)
    assert html =~ "Too many login attempts"
  end

  test "POST /login shows setup message when root hash is missing", %{conn: conn} do
    Application.delete_env(:aurum_finance, :root_password_hash)

    conn = post(conn, "/login", %{"auth" => %{"password" => "whatever"}})
    html = html_response(conn, 200)

    assert html =~ "AURUM_ROOT_PASSWORD_HASH is missing"
    refute html =~ "login-submit"
  end

  test "DELETE /logout clears session and redirects to /login", %{conn: conn} do
    conn =
      conn
      |> log_in_root()
      |> delete("/logout")

    assert redirected_to(conn) == "/login"
  end

  test "DELETE /logout redirects unauthenticated requests to /login", %{conn: conn} do
    conn = delete(conn, "/logout")

    assert redirected_to(conn) == "/login"
  end

  test "protected live route redirects to /login when unauthenticated", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/login"}}} = live(conn, "/dashboard")
  end
end
