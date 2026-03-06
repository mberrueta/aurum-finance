defmodule AurumFinance.AuthTest do
  use ExUnit.Case, async: true

  alias AurumFinance.Auth

  doctest AurumFinance.Auth

  setup do
    previous_hash = Application.get_env(:aurum_finance, :root_password_hash)
    new_hash = Bcrypt.hash_pwd_salt("correct-password")
    Application.put_env(:aurum_finance, :root_password_hash, new_hash)

    on_exit(fn ->
      if previous_hash do
        Application.put_env(:aurum_finance, :root_password_hash, previous_hash)
      else
        Application.delete_env(:aurum_finance, :root_password_hash)
      end
    end)

    :ok
  end

  test "ensure_configured!/0 validates root hash presence" do
    assert :ok = Auth.ensure_configured!()

    previous_hash = Application.get_env(:aurum_finance, :root_password_hash)
    Application.delete_env(:aurum_finance, :root_password_hash)

    assert_raise RuntimeError, ~r/AURUM_ROOT_PASSWORD_HASH is missing/, fn ->
      Auth.ensure_configured!()
    end

    Application.put_env(:aurum_finance, :root_password_hash, previous_hash)
  end

  test "valid_root_password?/1 verifies configured bcrypt hash" do
    assert Auth.valid_root_password?("correct-password")
    refute Auth.valid_root_password?("wrong-password")
    refute Auth.valid_root_password?(nil)
  end

  test "put_authenticated_session/2 stores auth and last-seen timestamps" do
    now = DateTime.from_unix!(1_700_000_000)

    session = Auth.put_authenticated_session(%{}, now)

    assert session["root_authenticated_at"] == 1_700_000_000
    assert session["root_last_seen_at"] == 1_700_000_000
  end

  test "validate_session/2 returns updated session when not idle expired" do
    auth_time = DateTime.from_unix!(1_700_000_000)
    now = DateTime.from_unix!(1_700_003_000)

    session = Auth.put_authenticated_session(%{}, auth_time)

    assert {:ok, validated} = Auth.validate_session(session, now)
    assert validated["root_authenticated_at"] == 1_700_000_000
    assert validated["root_last_seen_at"] == 1_700_003_000
  end

  test "validate_session/2 returns error when session is idle expired" do
    auth_time = DateTime.from_unix!(1_700_000_000)
    expired_now = DateTime.from_unix!(1_700_007_201)

    session = Auth.put_authenticated_session(%{}, auth_time)

    assert :error = Auth.validate_session(session, expired_now)
  end

  test "clear_authenticated_session/1 removes auth keys" do
    session =
      %{}
      |> Auth.put_authenticated_session(DateTime.from_unix!(1_700_000_000))
      |> Auth.clear_authenticated_session()

    refute Map.has_key?(session, "root_authenticated_at")
    refute Map.has_key?(session, "root_last_seen_at")
  end
end
