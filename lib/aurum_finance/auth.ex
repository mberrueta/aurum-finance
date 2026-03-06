defmodule AurumFinance.Auth do
  @moduledoc """
  Backend helpers for single-user root-password authentication.

  The root password hash is loaded from runtime config (`:root_password_hash`).
  Sessions are stored in Phoenix signed cookies, while idle timeout validation
  is enforced by this module's logic.
  """

  @auth_at_key "root_authenticated_at"
  @last_seen_at_key "root_last_seen_at"
  @idle_timeout_seconds 2 * 60 * 60

  @doc """
  Returns configured root password bcrypt hash.

  ## Examples

      iex> is_binary(AurumFinance.Auth.root_password_hash())
      true
  """
  @spec root_password_hash() :: String.t()
  def root_password_hash do
    case Application.get_env(:aurum_finance, :root_password_hash) do
      hash when is_binary(hash) and byte_size(hash) > 0 -> hash
      _ -> raise RuntimeError, missing_root_password_hash_error_message()
    end
  end

  @doc "Returns true when root password hash is configured."
  @spec configured?() :: boolean()
  def configured? do
    case Application.get_env(:aurum_finance, :root_password_hash) do
      hash when is_binary(hash) and byte_size(hash) > 0 -> true
      _ -> false
    end
  end

  @doc "Returns the missing-hash setup message shown in the login UI."
  @spec missing_root_password_hash_error_message() :: String.t()
  def missing_root_password_hash_error_message do
    [
      Gettext.dgettext(
        AurumFinanceWeb.Gettext,
        "errors",
        "error_missing_root_password_hash"
      ),
      Gettext.dgettext(
        AurumFinanceWeb.Gettext,
        "errors",
        "error_missing_root_password_hash_hint"
      )
    ]
    |> Enum.join("\n")
  end

  @doc """
  Raises when root password hash is not configured.

  ## Examples

      iex> AurumFinance.Auth.ensure_configured!()
      :ok
  """
  @spec ensure_configured!() :: :ok
  def ensure_configured! do
    _hash = root_password_hash()
    :ok
  end

  @doc """
  Verifies a plain password against configured bcrypt hash.

  ## Examples

      iex> AurumFinance.Auth.valid_root_password?(nil)
      false
  """
  @spec valid_root_password?(term()) :: boolean()
  def valid_root_password?(password) when is_binary(password) and byte_size(password) > 0 do
    bcrypt_verify_pass(password, root_password_hash())
  end

  def valid_root_password?(_), do: false

  @doc """
  Creates or updates an authenticated session map.

  ## Examples

      iex> now = DateTime.from_unix!(1_700_000_000)
      iex> session = AurumFinance.Auth.put_authenticated_session(%{}, now)
      iex> session["root_authenticated_at"]
      1700000000
      iex> session["root_last_seen_at"]
      1700000000
  """
  @spec put_authenticated_session(map(), DateTime.t()) :: map()
  def put_authenticated_session(session, now \\ DateTime.utc_now()) when is_map(session) do
    unix_now = DateTime.to_unix(now, :second)

    session
    |> Map.put(@auth_at_key, unix_now)
    |> Map.put(@last_seen_at_key, unix_now)
  end

  @doc """
  Removes auth-related keys from session map.

  ## Examples

      iex> now = DateTime.from_unix!(1_700_000_000)
      iex> session = AurumFinance.Auth.put_authenticated_session(%{}, now)
      iex> cleared = AurumFinance.Auth.clear_authenticated_session(session)
      iex> Map.has_key?(cleared, "root_authenticated_at")
      false
  """
  @spec clear_authenticated_session(map()) :: map()
  def clear_authenticated_session(session) when is_map(session) do
    session
    |> Map.delete(@auth_at_key)
    |> Map.delete(@last_seen_at_key)
  end

  @doc """
  Validates session freshness and refreshes last-seen timestamp.

  Returns `{:ok, updated_session}` when session is authenticated and not idle-expired.
  Returns `:error` when session is missing auth keys or has expired.

  ## Examples

      iex> session = %{"root_authenticated_at" => 1_700_000_000, "root_last_seen_at" => 1_700_000_000}
      iex> now = DateTime.from_unix!(1_700_000_100)
      iex> {:ok, updated} = AurumFinance.Auth.validate_session(session, now)
      iex> updated["root_last_seen_at"]
      1700000100

      iex> session = %{"root_authenticated_at" => 1_700_000_000, "root_last_seen_at" => 1_700_000_000}
      iex> expired = DateTime.from_unix!(1_700_007_201)
      iex> AurumFinance.Auth.validate_session(session, expired)
      :error
  """
  @spec validate_session(map(), DateTime.t()) :: {:ok, map()} | :error
  def validate_session(session, now \\ DateTime.utc_now())

  def validate_session(session, now) when is_map(session) do
    unix_now = DateTime.to_unix(now, :second)

    with auth_at when is_integer(auth_at) <- Map.get(session, @auth_at_key),
         last_seen_at when is_integer(last_seen_at) <- Map.get(session, @last_seen_at_key),
         true <- unix_now - last_seen_at <= @idle_timeout_seconds do
      {:ok, Map.put(session, @last_seen_at_key, unix_now)}
    else
      _ -> :error
    end
  end

  def validate_session(_session, _now), do: :error

  @doc """
  Returns idle-timeout in seconds.

  ## Examples

      iex> AurumFinance.Auth.idle_timeout_seconds()
      7200
  """
  @spec idle_timeout_seconds() :: pos_integer()
  def idle_timeout_seconds, do: @idle_timeout_seconds

  defp bcrypt_verify_pass(password, hash) do
    case Code.ensure_loaded(Bcrypt) do
      {:module, Bcrypt} -> apply(Bcrypt, :verify_pass, [password, hash])
      _ -> raise RuntimeError, "bcrypt dependency is not available"
    end
  end
end
