defmodule AurumFinanceWeb.AuthController do
  @moduledoc """
  Handles root-auth login/logout HTTP endpoints.

  This controller implements the approved single-user flow:
  `GET /login`, `POST /login`, and `DELETE /logout`.
  """

  use AurumFinanceWeb, :controller

  alias AurumFinance.Auth
  alias AurumFinanceWeb.AuthRateLimiter
  alias AurumFinanceWeb.RootAuth

  @doc "Renders the password-only login page."
  def new(conn, _params) do
    render(conn, :login,
      form: Phoenix.Component.to_form(%{}, as: :auth),
      root_auth_configured?: Auth.configured?(),
      missing_hash_message: Auth.missing_root_password_hash_error_message()
    )
  end

  @doc "Authenticates root password and starts a signed-cookie session."
  def create(conn, %{"auth" => %{"password" => password}}) do
    ip_key = AuthRateLimiter.key_from_conn(conn)

    cond do
      not Auth.configured?() ->
        render_missing_hash(conn)

      AuthRateLimiter.allow_login_attempt?(ip_key) == :error ->
        conn
        |> put_flash(:error, dgettext("auth", "error_too_many_login_attempts"))
        |> render_login()

      Auth.valid_root_password?(password) ->
        _ = AuthRateLimiter.clear_attempts(ip_key)

        conn
        |> RootAuth.log_in_root()
        |> put_flash(:info, dgettext("auth", "msg_login_success"))
        |> redirect(to: "/")

      true ->
        _ = AuthRateLimiter.register_failed_attempt(ip_key)

        conn
        |> put_flash(:error, dgettext("auth", "error_invalid_password"))
        |> render_login()
    end
  end

  def create(conn, _params) do
    conn
    |> put_flash(:error, dgettext("auth", "error_invalid_password"))
    |> render_login()
  end

  @doc "Logs out current root session and redirects to login."
  def delete(conn, _params) do
    conn
    |> RootAuth.log_out_root()
    |> put_flash(:info, dgettext("auth", "msg_logged_out"))
    |> redirect(to: "/login")
  end

  defp render_login(conn) do
    render(conn, :login,
      form: Phoenix.Component.to_form(%{}, as: :auth),
      root_auth_configured?: Auth.configured?(),
      missing_hash_message: Auth.missing_root_password_hash_error_message()
    )
  end

  defp render_missing_hash(conn) do
    conn
    |> put_flash(:error, Auth.missing_root_password_hash_error_message())
    |> render(:login,
      form: Phoenix.Component.to_form(%{}, as: :auth),
      root_auth_configured?: false,
      missing_hash_message: Auth.missing_root_password_hash_error_message()
    )
  end
end
