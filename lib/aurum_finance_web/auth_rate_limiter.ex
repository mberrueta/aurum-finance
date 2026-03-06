defmodule AurumFinanceWeb.AuthRateLimiter do
  @moduledoc """
  Simple in-memory, IP-based rate limiter for login attempts.

  This limiter is intentionally lightweight and process-local.
  It is suitable as a baseline hardening layer for self-hosted deployments.
  """

  @table :aurum_auth_rate_limiter
  @window_seconds 300
  @max_failed_attempts 5
  @lockout_seconds 300

  @doc """
  Builds a stable rate-limit key from the client connection.

  ## Examples

      iex> AurumFinanceWeb.AuthRateLimiter.key_from_conn(%Plug.Conn{remote_ip: {127, 0, 0, 1}})
      "127.0.0.1"
  """
  @spec key_from_conn(Plug.Conn.t()) :: String.t()
  def key_from_conn(%Plug.Conn{remote_ip: remote_ip}) when is_tuple(remote_ip) do
    remote_ip
    |> :inet.ntoa()
    |> to_string()
  end

  def key_from_conn(_conn), do: "unknown"

  @doc """
  Returns `:ok` when login attempts are allowed, otherwise `:error`.

  ## Examples

      iex> :ok = AurumFinanceWeb.AuthRateLimiter.reset!()
      iex> AurumFinanceWeb.AuthRateLimiter.allow_login_attempt?("127.0.0.1", 1_700_000_000)
      :ok
  """
  @spec allow_login_attempt?(String.t(), integer()) :: :ok | :error
  def allow_login_attempt?(ip_key, now \\ now_seconds()) when is_binary(ip_key) do
    ensure_table!()

    case :ets.lookup(@table, ip_key) do
      [] ->
        :ok

      [{^ip_key, failures, blocked_until}] ->
        pruned = prune_failures(failures, now)

        if pruned != failures do
          :ets.insert(@table, {ip_key, pruned, blocked_until})
        end

        if blocked_until > now, do: :error, else: :ok
    end
  end

  @doc """
  Registers a failed login attempt for the given client key.

  ## Examples

      iex> :ok = AurumFinanceWeb.AuthRateLimiter.reset!()
      iex> :ok = AurumFinanceWeb.AuthRateLimiter.register_failed_attempt("127.0.0.1", 1_700_000_000)
      iex> AurumFinanceWeb.AuthRateLimiter.allow_login_attempt?("127.0.0.1", 1_700_000_001)
      :ok
  """
  @spec register_failed_attempt(String.t(), integer()) :: :ok
  def register_failed_attempt(ip_key, now \\ now_seconds()) when is_binary(ip_key) do
    ensure_table!()

    {failures, blocked_until} =
      case :ets.lookup(@table, ip_key) do
        [] ->
          {[], 0}

        [{^ip_key, existing_failures, existing_blocked_until}] ->
          {existing_failures, existing_blocked_until}
      end

    updated_failures = [now | prune_failures(failures, now)]

    updated_blocked_until =
      if length(updated_failures) >= @max_failed_attempts do
        now + @lockout_seconds
      else
        blocked_until
      end

    :ets.insert(@table, {ip_key, updated_failures, updated_blocked_until})
    :ok
  end

  @doc """
  Clears stored attempts for a client key (used after successful login).

  ## Examples

      iex> :ok = AurumFinanceWeb.AuthRateLimiter.reset!()
      iex> Enum.each(1..5, fn step -> AurumFinanceWeb.AuthRateLimiter.register_failed_attempt("127.0.0.1", 1_700_000_000 + step) end)
      :ok
      iex> AurumFinanceWeb.AuthRateLimiter.allow_login_attempt?("127.0.0.1", 1_700_000_006)
      :error
      iex> :ok = AurumFinanceWeb.AuthRateLimiter.clear_attempts("127.0.0.1")
      iex> AurumFinanceWeb.AuthRateLimiter.allow_login_attempt?("127.0.0.1", 1_700_000_007)
      :ok
  """
  @spec clear_attempts(String.t()) :: :ok
  def clear_attempts(ip_key) when is_binary(ip_key) do
    ensure_table!()
    _ = :ets.delete(@table, ip_key)
    :ok
  end

  @doc """
  Resets all limiter state (test helper).

  ## Examples

      iex> AurumFinanceWeb.AuthRateLimiter.reset!()
      :ok
  """
  @spec reset!() :: :ok
  def reset! do
    case :ets.whereis(@table) do
      :undefined ->
        :ok

      _ ->
        :ets.delete_all_objects(@table)
        :ok
    end
  end

  defp ensure_table! do
    case :ets.whereis(@table) do
      :undefined ->
        _ =
          :ets.new(@table, [
            :named_table,
            :set,
            :public,
            read_concurrency: true,
            write_concurrency: true
          ])

        :ok

      _ ->
        :ok
    end
  rescue
    ArgumentError -> :ok
  end

  defp prune_failures(failures, now) do
    Enum.filter(failures, fn ts -> now - ts <= @window_seconds end)
  end

  defp now_seconds, do: System.system_time(:second)
end
