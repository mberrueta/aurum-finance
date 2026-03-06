defmodule AurumFinanceWeb.RootAuth do
  @behaviour Plug

  @moduledoc """
  Web auth integration for single-user root-password access.

  Session data is stored in Phoenix signed cookies, while idle-timeout
  validation is enforced by `AurumFinance.Auth`.
  """

  use Gettext, backend: AurumFinanceWeb.Gettext

  import Plug.Conn
  alias AurumFinance.Auth

  @doc "Initializes plug action dispatch for auth pipelines."
  def init(action), do: action

  @doc "Dispatches plug call to the configured auth action."
  def call(conn, action)
      when action in [:require_authenticated_root, :redirect_if_root_authenticated] do
    apply(__MODULE__, action, [conn, []])
  end

  @doc "Stores a freshly authenticated root session in the cookie session."
  @spec log_in_root(Plug.Conn.t()) :: Plug.Conn.t()
  def log_in_root(conn) do
    session = Auth.put_authenticated_session(%{}, DateTime.utc_now())

    conn
    |> configure_session(renew: true)
    |> clear_session()
    |> put_session_map(session)
  end

  @doc "Drops root session from cookie session."
  @spec log_out_root(Plug.Conn.t()) :: Plug.Conn.t()
  def log_out_root(conn) do
    configure_session(conn, drop: true)
  end

  @doc "Redirects to login page when no valid root session is available."
  @spec require_authenticated_root(Plug.Conn.t(), term()) :: Plug.Conn.t()
  def require_authenticated_root(conn, _opts) do
    case Auth.validate_session(get_session(conn), DateTime.utc_now()) do
      {:ok, updated_session} ->
        conn
        |> put_session_map(updated_session)
        |> Plug.Conn.assign(:current_scope, %{root: true})

      :error ->
        conn
        |> configure_session(drop: true)
        |> Phoenix.Controller.put_flash(:error, dgettext("auth", "error_login_required"))
        |> Phoenix.Controller.redirect(to: "/login")
        |> halt()
    end
  end

  @doc "Redirects authenticated users away from the login route."
  @spec redirect_if_root_authenticated(Plug.Conn.t(), term()) :: Plug.Conn.t()
  def redirect_if_root_authenticated(conn, _opts) do
    case Auth.validate_session(get_session(conn), DateTime.utc_now()) do
      {:ok, updated_session} ->
        conn
        |> put_session_map(updated_session)
        |> Phoenix.Controller.redirect(to: "/")
        |> halt()

      :error ->
        conn
    end
  end

  @doc "LiveView on_mount callback for root-session enforcement."
  @spec on_mount(:ensure_authenticated, map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:cont | :halt, Phoenix.LiveView.Socket.t()}
  def on_mount(:ensure_authenticated, _params, session, socket) do
    case Auth.validate_session(session, DateTime.utc_now()) do
      {:ok, _updated_session} ->
        {:cont, Phoenix.Component.assign(socket, :current_scope, %{root: true})}

      :error ->
        {:halt,
         socket
         |> Phoenix.LiveView.put_flash(:error, dgettext("auth", "error_login_required"))
         |> Phoenix.LiveView.redirect(to: "/login")}
    end
  end

  defp put_session_map(conn, session_map) do
    Enum.reduce(session_map, conn, fn {key, value}, acc_conn ->
      put_session(acc_conn, key, value)
    end)
  end
end
