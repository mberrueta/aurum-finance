defmodule Mix.Tasks.Aurum.GenPasswordHash do
  use Mix.Task

  @shortdoc "Generates a bcrypt hash for Aurum root password"

  @moduledoc """
  Generates a bcrypt hash for the root password.

  Usage:

      mix aurum.gen_password_hash <password>
  """

  @impl Mix.Task
  def run([password]) when is_binary(password) and byte_size(password) > 0 do
    Mix.shell().info(Bcrypt.hash_pwd_salt(password))
  end

  def run(_args) do
    raise Mix.Error, "Usage: mix aurum.gen_password_hash <password>"
  end
end
