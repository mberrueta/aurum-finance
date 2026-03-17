defmodule AurumFinance.Classification.ExpressionCompiler do
  @moduledoc """
  Compiles structured rule-builder conditions into the AurumFinance DSL string.
  """

  alias AurumFinance.Classification.ExpressionValidator

  @doc """
  Compiles a non-empty list of condition maps into one DSL expression.

  ## Examples

      iex> AurumFinance.Classification.ExpressionCompiler.compile([
      ...>   %{field: :description, operator: :contains, value: "Uber", negate: false},
      ...>   %{field: :amount, operator: :less_than, value: "-10", negate: false}
      ...> ])
      {:ok, "(description contains \\"Uber\\") AND (amount < -10)"}
  """
  @spec compile([map()]) :: {:ok, String.t()} | {:error, atom()}
  def compile([]), do: {:error, :empty_conditions}
  def compile(nil), do: {:error, :empty_conditions}

  def compile(conditions) when is_list(conditions) do
    case compile_conditions(conditions) do
      {:ok, compiled_conditions} ->
        compiled_conditions
        |> Enum.map_join(" AND ", &wrap_condition/1)
        |> ExpressionValidator.validate_expression()

      {:error, reason} ->
        {:error, reason}
    end
  end

  def compile(_conditions), do: {:error, :invalid_conditions}

  defp compile_conditions(conditions) do
    Enum.reduce_while(conditions, {:ok, []}, fn condition, {:ok, acc} ->
      case compile_condition(condition) do
        {:ok, compiled} -> {:cont, {:ok, acc ++ [compiled]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp compile_condition(condition) do
    with {:ok, field} <- normalize_field(fetch_condition_value(condition, :field)),
         {:ok, operator} <- normalize_operator(fetch_condition_value(condition, :operator)),
         :ok <- validate_condition_field_value(field, operator, condition),
         {:ok, base_condition} <- build_base_condition(field, operator, condition) do
      {:ok, maybe_negate(base_condition, fetch_condition_value(condition, :negate))}
    end
  end

  defp normalize_field(field), do: ExpressionValidator.normalize_field(field)
  defp normalize_operator(operator), do: ExpressionValidator.normalize_operator(operator)

  defp validate_condition_field_value(field, operator, condition) do
    value = fetch_condition_value(condition, :value)

    if valid_condition_value?(ExpressionValidator.field_type(field), operator, value) do
      :ok
    else
      {:error, :invalid_condition_value}
    end
  end

  defp build_base_condition(field, operator, condition) do
    field_token = Atom.to_string(field)

    case operator do
      unary when unary in [:is_empty, :is_not_empty] ->
        {:ok, "#{field_token} #{operator_token(unary)}"}

      _ ->
        value = fetch_condition_value(condition, :value)
        {:ok, "#{field_token} #{operator_token(operator)} #{literal_token(field, value)}"}
    end
  end

  defp maybe_negate(condition, value) when value in [true, "true"], do: "NOT (#{condition})"
  defp maybe_negate(condition, _value), do: condition

  defp wrap_condition(condition), do: "(#{condition})"

  defp operator_token(:equals), do: "equals"
  defp operator_token(:contains), do: "contains"
  defp operator_token(:starts_with), do: "starts_with"
  defp operator_token(:ends_with), do: "ends_with"
  defp operator_token(:matches_regex), do: "matches_regex"
  defp operator_token(:greater_than), do: ">"
  defp operator_token(:less_than), do: "<"
  defp operator_token(:greater_than_or_equal), do: ">="
  defp operator_token(:less_than_or_equal), do: "<="
  defp operator_token(:is_empty), do: "is_empty"
  defp operator_token(:is_not_empty), do: "is_not_empty"

  defp literal_token(field, value) do
    case ExpressionValidator.field_type(field) do
      :string ->
        escaped_value =
          value
          |> to_string()
          |> String.replace("\\", "\\\\")
          |> String.replace("\"", "\\\"")

        ~s("#{escaped_value}")

      :decimal ->
        decimal_to_string(value)

      :date ->
        date_to_string(value)
    end
  end

  defp decimal_to_string(%Decimal{} = decimal), do: Decimal.to_string(decimal)
  defp decimal_to_string(value) when is_integer(value), do: Integer.to_string(value)

  defp decimal_to_string(value) when is_float(value),
    do: :erlang.float_to_binary(value, [:compact])

  defp decimal_to_string(value), do: String.trim(to_string(value))

  defp date_to_string(%Date{} = date), do: Date.to_iso8601(date)
  defp date_to_string(value), do: String.trim(to_string(value))

  defp fetch_condition_value(condition, key) when is_map(condition) do
    Map.get(condition, key) || Map.get(condition, Atom.to_string(key))
  end

  defp valid_condition_value?(_type, operator, _value)
       when operator in [:is_empty, :is_not_empty],
       do: true

  defp valid_condition_value?(:string, _operator, value), do: is_binary(value)
  defp valid_condition_value?(:decimal, _operator, %Decimal{}), do: true

  defp valid_condition_value?(:decimal, _operator, value),
    do: is_binary(value) or is_integer(value) or is_float(value)

  defp valid_condition_value?(:date, _operator, %Date{}), do: true
  defp valid_condition_value?(:date, _operator, value), do: is_binary(value)
end
