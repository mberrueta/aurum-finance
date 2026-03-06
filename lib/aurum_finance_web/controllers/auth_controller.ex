defmodule AurumFinanceWeb.AuthController do
  @moduledoc """
  Handles root-auth login/logout HTTP endpoints.

  This controller implements the approved single-user flow:
  `GET /login`, `POST /login`, and `DELETE /logout`.
  """

  use AurumFinanceWeb, :controller

  alias AurumFinance.Auth
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
    cond do
      not Auth.configured?() ->
        conn
        |> put_flash(:error, Auth.missing_root_password_hash_error_message())
        |> render(:login,
          form: Phoenix.Component.to_form(%{}, as: :auth),
          root_auth_configured?: false,
          missing_hash_message: Auth.missing_root_password_hash_error_message()
        )

      Auth.valid_root_password?(password) ->
        conn
        |> RootAuth.log_in_root()
        |> put_flash(:info, dgettext("auth", "msg_login_success"))
        |> redirect(to: "/")

      true ->
        conn
        |> put_flash(:error, dgettext("auth", "error_invalid_password"))
        |> render(:login,
          form: Phoenix.Component.to_form(%{}, as: :auth),
          root_auth_configured?: true,
          missing_hash_message: Auth.missing_root_password_hash_error_message()
        )
    end
  end

  def create(conn, _params) do
    conn
    |> put_flash(:error, dgettext("auth", "error_invalid_password"))
    |> render(:login,
      form: Phoenix.Component.to_form(%{}, as: :auth),
      root_auth_configured?: Auth.configured?(),
      missing_hash_message: Auth.missing_root_password_hash_error_message()
    )
  end

  @doc "Logs out current root session and redirects to login."
  def delete(conn, _params) do
    conn
    |> RootAuth.log_out_root()
    |> put_flash(:info, dgettext("auth", "msg_logged_out"))
    |> redirect(to: "/login")
  end
end
