defmodule AurumFinance.Classification.Types.StringList do
  @moduledoc """
  JSONB-backed Ecto type for lists of strings.

  Classification tags are stored in a JSONB column but surfaced as a plain
  Elixir list. Non-string entries are rejected during casting and loading.
  """

  @behaviour Ecto.Type

  @impl true
  def type, do: :map

  @impl true
  def embed_as(_format), do: :self

  @impl true
  def equal?(left, right), do: left == right

  @impl true
  def cast(nil), do: {:ok, []}

  def cast(value) when is_list(value) do
    if Enum.all?(value, &is_binary/1) do
      {:ok, value}
    else
      :error
    end
  end

  def cast(_value), do: :error

  @impl true
  def load(nil), do: {:ok, []}

  def load(value) when is_list(value) do
    if Enum.all?(value, &is_binary/1) do
      {:ok, value}
    else
      :error
    end
  end

  def load(_value), do: :error

  @impl true
  def dump(nil), do: {:ok, []}

  def dump(value) when is_list(value) do
    if Enum.all?(value, &is_binary/1) do
      {:ok, value}
    else
      :error
    end
  end

  def dump(_value), do: :error
end
