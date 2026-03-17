defmodule AurumFinance.Classification.Engine.DslEvaluator do
  @moduledoc """
  AurumFinance-owned DSL evaluator backend used by `Classification.Engine`.

  The public rules DSL stays stable while this module hides the concrete
  evaluation strategy. Today it evaluates the parsed AST from
  `ExpressionValidator`; a future backend may swap to another implementation
  without changing stored rule expressions.
  """

  @behaviour AurumFinance.Classification.ExpressionEvaluator

  alias AurumFinance.Classification.ExpressionValidator
  alias Decimal, as: D

  @impl true
  def compile(expression) when is_binary(expression) do
    case ExpressionValidator.validate_expression(expression) do
      {:ok, normalized} -> ExpressionValidator.parse_expression(normalized)
      {:error, reason} -> {:error, reason}
    end
  end

  def compile(_expression), do: {:error, :invalid_expression}

  @impl true
  def evaluate(compiled_expression, facts) when is_map(facts) do
    {:ok, eval_ast(compiled_expression, facts)}
  rescue
    _error -> {:error, :invalid_expression}
  end

  def evaluate(_compiled_expression, _facts), do: {:error, :invalid_expression}

  defp eval_ast({:and, nodes}, facts) when is_list(nodes) do
    Enum.all?(nodes, &eval_ast(&1, facts))
  end

  defp eval_ast({:not, node}, facts), do: not eval_ast(node, facts)

  defp eval_ast({:condition, field, operator, expected}, facts) do
    compare(Map.get(facts, field), operator, expected)
  end

  defp compare(value, :equals, expected) when is_binary(expected) do
    normalize_string(value) == normalize_string(expected)
  end

  defp compare(value, :contains, expected) when is_binary(expected) do
    case normalize_string(value) do
      nil -> false
      normalized -> String.contains?(normalized, normalize_string(expected))
    end
  end

  defp compare(value, :starts_with, expected) when is_binary(expected) do
    case normalize_string(value) do
      nil -> false
      normalized -> String.starts_with?(normalized, normalize_string(expected))
    end
  end

  defp compare(value, :ends_with, expected) when is_binary(expected) do
    case normalize_string(value) do
      nil -> false
      normalized -> String.ends_with?(normalized, normalize_string(expected))
    end
  end

  defp compare(value, :matches_regex, expected) when is_binary(expected) do
    case {value, Regex.compile(expected)} do
      {nil, _compiled} -> false
      {_value, {:error, _reason}} -> false
      {source, {:ok, regex}} -> Regex.match?(regex, stringify(source))
    end
  end

  defp compare(value, :greater_than, %D{} = expected), do: decimal_compare(value, expected) == :gt
  defp compare(value, :less_than, %D{} = expected), do: decimal_compare(value, expected) == :lt

  defp compare(value, :greater_than_or_equal, %D{} = expected),
    do: decimal_compare(value, expected) in [:gt, :eq]

  defp compare(value, :less_than_or_equal, %D{} = expected),
    do: decimal_compare(value, expected) in [:lt, :eq]

  defp compare(value, :greater_than, %Date{} = expected), do: date_compare(value, expected) == :gt
  defp compare(value, :less_than, %Date{} = expected), do: date_compare(value, expected) == :lt

  defp compare(value, :greater_than_or_equal, %Date{} = expected),
    do: date_compare(value, expected) in [:gt, :eq]

  defp compare(value, :less_than_or_equal, %Date{} = expected),
    do: date_compare(value, expected) in [:lt, :eq]

  defp compare(value, :equals, %D{} = expected), do: decimal_compare(value, expected) == :eq
  defp compare(value, :equals, %Date{} = expected), do: date_compare(value, expected) == :eq
  defp compare(value, :is_empty, nil), do: value in [nil, ""]
  defp compare(value, :is_not_empty, nil), do: value not in [nil, ""]
  defp compare(_value, _operator, _expected), do: false

  defp decimal_compare(nil, _expected), do: :error

  defp decimal_compare(%D{} = value, %D{} = expected) do
    D.compare(value, expected)
  end

  defp decimal_compare(value, %D{} = expected) when is_binary(value) do
    case D.parse(value) do
      {decimal, ""} -> D.compare(decimal, expected)
      _ -> :error
    end
  end

  defp decimal_compare(_value, _expected), do: :error

  defp date_compare(%Date{} = value, %Date{} = expected), do: Date.compare(value, expected)
  defp date_compare(_value, _expected), do: :error

  defp normalize_string(nil), do: nil
  defp normalize_string(value), do: value |> stringify() |> String.downcase()

  defp stringify(value) when is_binary(value), do: value
  defp stringify(value) when is_atom(value), do: Atom.to_string(value)
  defp stringify(value), do: to_string(value)
end
