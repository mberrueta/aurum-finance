defmodule Mix.Tasks.Aurum.GenPasswordHashTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  test "prints bcrypt hash only" do
    Mix.Task.reenable("aurum.gen_password_hash")

    output =
      capture_io(fn ->
        Mix.Tasks.Aurum.GenPasswordHash.run(["super-secret-password"])
      end)
      |> String.trim()

    assert output =~ ~r/^\$2[abxy]\$\d{2}\$[\.\/A-Za-z0-9]{53}$/
    assert Bcrypt.verify_pass("super-secret-password", output)
  end

  test "raises usage for invalid args" do
    Mix.Task.reenable("aurum.gen_password_hash")

    assert_raise Mix.Error, "Usage: mix aurum.gen_password_hash <password>", fn ->
      Mix.Tasks.Aurum.GenPasswordHash.run([])
    end
  end
end
