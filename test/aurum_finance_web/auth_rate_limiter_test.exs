defmodule AurumFinanceWeb.AuthRateLimiterTest do
  use ExUnit.Case

  alias AurumFinanceWeb.AuthRateLimiter

  doctest AurumFinanceWeb.AuthRateLimiter

  setup do
    :ok = AuthRateLimiter.reset!()

    on_exit(fn ->
      :ok = AuthRateLimiter.reset!()
    end)

    :ok
  end

  test "blocks after repeated failures and allows again after clear" do
    ip = "127.0.0.1"
    now = 1_700_000_000

    assert :ok = AuthRateLimiter.allow_login_attempt?(ip, now)

    Enum.each(1..5, fn offset ->
      :ok = AuthRateLimiter.register_failed_attempt(ip, now + offset)
    end)

    assert :error = AuthRateLimiter.allow_login_attempt?(ip, now + 6)

    :ok = AuthRateLimiter.clear_attempts(ip)

    assert :ok = AuthRateLimiter.allow_login_attempt?(ip, now + 7)
  end

  test "prunes old failures outside the rolling window" do
    ip = "127.0.0.1"
    base = 1_700_000_000

    :ok = AuthRateLimiter.register_failed_attempt(ip, base)
    assert :ok = AuthRateLimiter.allow_login_attempt?(ip, base + 301)
  end
end
