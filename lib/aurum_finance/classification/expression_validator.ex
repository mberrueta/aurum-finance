defmodule AurumFinance.Classification.ExpressionValidator do
  @moduledoc """
  Validates AurumFinance rule expressions and exposes the supported DSL catalog.

  The validator understands AurumFinance-owned syntax only. It does not depend
  on any runtime evaluation library.
  """

  alias AurumFinance.Classification.ExpressionEvaluator

  @string_fields [
    :description,
    :currency_code,
    :source_type,
    :account_name,
    :account_type,
    :institution_name
  ]
  @decimal_fields [:amount, :abs_amount]
  @date_fields [:date]
  @fields @string_fields ++ @decimal_fields ++ @date_fields

  @operators %{
    "equals" => :equals,
    "contains" => :contains,
    "starts_with" => :starts_with,
    "ends_with" => :ends_with,
    "matches_regex" => :matches_regex,
    ">" => :greater_than,
    "<" => :less_than,
    ">=" => :greater_than_or_equal,
    "<=" => :less_than_or_equal,
    "is_empty" => :is_empty,
    "is_not_empty" => :is_not_empty
  }
  @operator_values Map.values(@operators)

  @type expression_ast :: ExpressionEvaluator.expression_ast()

  @doc false
  @spec supported_fields() :: [ExpressionEvaluator.field()]
  def supported_fields, do: @fields

  @doc false
  @spec supported_operators() :: [ExpressionEvaluator.operator()]
  def supported_operators, do: @operator_values

  @doc false
  @spec field_type(ExpressionEvaluator.field()) :: :string | :decimal | :date
  def field_type(field) when field in @string_fields, do: :string
  def field_type(field) when field in @decimal_fields, do: :decimal
  def field_type(field) when field in @date_fields, do: :date

  @doc false
  @spec normalize_field(atom() | String.t() | nil) :: {:ok, ExpressionEvaluator.field()} | :error
  def normalize_field(field) when is_atom(field) and field in @fields, do: {:ok, field}

  def normalize_field(field) when is_binary(field) do
    field
    |> String.trim()
    |> case do
      "" -> :error
      value -> normalize_existing_field(value)
    end
  end

  def normalize_field(_field), do: :error

  @doc false
  @spec normalize_operator(atom() | String.t() | nil) ::
          {:ok, ExpressionEvaluator.operator()} | :error
  def normalize_operator(operator) when is_atom(operator) do
    if operator in @operator_values, do: {:ok, operator}, else: :error
  end

  def normalize_operator(operator) when is_binary(operator) do
    operator
    |> String.trim()
    |> case do
      "" -> :error
      token -> Map.fetch(@operators, token)
    end
    |> case do
      {:ok, normalized} -> {:ok, normalized}
      :error -> :error
    end
  end

  def normalize_operator(_operator), do: :error

  @doc """
  Validates one AurumFinance expression string.

  ## Examples

      iex> AurumFinance.Classification.ExpressionValidator.validate_expression(
      ...>   ~s|description contains "Uber"|
      ...> )
      {:ok, "description contains \\"Uber\\""}

      iex> AurumFinance.Classification.ExpressionValidator.validate_expression(
      ...>   ~s|memo contains "Uber"|
      ...> )
      {:error, :invalid_expression}
  """
  @spec validate_expression(String.t() | nil) :: {:ok, String.t()} | {:error, atom()}
  def validate_expression(expression) when is_binary(expression) do
    expression = String.trim(expression)

    with false <- expression == "",
         {:ok, _ast} <- parse_expression(expression) do
      {:ok, expression}
    else
      true -> {:error, :empty_expression}
      {:error, reason} -> {:error, reason}
    end
  end

  def validate_expression(_expression), do: {:error, :invalid_expression}

  @doc false
  @spec parse_expression(String.t()) :: {:ok, expression_ast()} | {:error, atom()}
  def parse_expression(expression) do
    with {:ok, tokens} <- tokenize(expression),
         {:ok, ast, []} <- parse_and_expression(tokens) do
      {:ok, ast}
    else
      {:ok, _ast, _remaining} -> {:error, :invalid_expression}
      {:error, reason} -> {:error, reason}
    end
  end

  defp normalize_existing_field(field) do
    case Enum.find(@fields, &(Atom.to_string(&1) == field)) do
      nil -> :error
      normalized -> {:ok, normalized}
    end
  end

  defp tokenize(expression), do: tokenize(String.trim_leading(expression), [])

  defp tokenize("", tokens), do: {:ok, Enum.reverse(tokens)}

  defp tokenize(expression, tokens) do
    case Regex.run(
           ~r/^(>=|<=|>|<|\(|\)|AND|NOT|equals|contains|starts_with|ends_with|matches_regex|is_empty|is_not_empty|"(?:[^"\\]|\\.)*"|\d{4}-\d{2}-\d{2}|-?\d+(?:\.\d+)?|[A-Za-z_][A-Za-z0-9_]*)\s*/,
           expression
         ) do
      [match, token] ->
        rest = String.replace_prefix(expression, match, "")
        tokenize(rest, [token | tokens])

      _ ->
        {:error, :invalid_expression}
    end
  end

  defp parse_and_expression(tokens) do
    with {:ok, first, rest} <- parse_term(tokens) do
      parse_and_expression_rest(first, rest)
    end
  end

  defp parse_and_expression_rest(left, ["AND" | rest]) do
    with {:ok, right, remaining} <- parse_term(rest) do
      combined =
        case left do
          {:and, nodes} -> {:and, nodes ++ [right]}
          _ -> {:and, [left, right]}
        end

      parse_and_expression_rest(combined, remaining)
    end
  end

  defp parse_and_expression_rest(ast, rest), do: {:ok, ast, rest}

  defp parse_term(["NOT", "(" | rest]) do
    case parse_and_expression(rest) do
      {:ok, ast, [")" | remaining]} -> {:ok, {:not, ast}, remaining}
      _ -> {:error, :invalid_expression}
    end
  end

  defp parse_term(["(" | rest]) do
    case parse_and_expression(rest) do
      {:ok, ast, [")" | remaining]} -> {:ok, ast, remaining}
      _ -> {:error, :invalid_expression}
    end
  end

  defp parse_term(tokens), do: parse_condition(tokens)

  defp parse_condition([field_token, operator_token | rest]) do
    with {:ok, field} <- normalize_field(field_token),
         {:ok, operator} <- normalize_operator(operator_token),
         :ok <- validate_field_operator(field, operator) do
      parse_condition_value(field, operator, rest)
    else
      :error -> {:error, :invalid_expression}
      {:error, _reason} = error -> error
    end
  end

  defp parse_condition(_tokens), do: {:error, :invalid_expression}

  defp parse_condition_value(field, operator, rest)
       when operator in [:is_empty, :is_not_empty] do
    {:ok, {:condition, field, operator, nil}, rest}
  end

  defp parse_condition_value(field, operator, [value_token | rest]) do
    with {:ok, value} <- parse_typed_value(field, operator, value_token) do
      {:ok, {:condition, field, operator, value}, rest}
    end
  end

  defp parse_condition_value(_field, _operator, []), do: {:error, :invalid_expression}

  defp validate_field_operator(field, operator) do
    allowed? =
      case field_type(field) do
        :string ->
          operator in [
            :equals,
            :contains,
            :starts_with,
            :ends_with,
            :matches_regex,
            :is_empty,
            :is_not_empty
          ]

        :decimal ->
          operator in [
            :equals,
            :greater_than,
            :less_than,
            :greater_than_or_equal,
            :less_than_or_equal
          ]

        :date ->
          operator in [
            :equals,
            :greater_than,
            :less_than,
            :greater_than_or_equal,
            :less_than_or_equal
          ]
      end

    if allowed?, do: :ok, else: {:error, :invalid_expression}
  end

  defp parse_typed_value(_field, :matches_regex, token) do
    with {:ok, value} <- parse_string_literal(token),
         {:ok, _compiled} <- Regex.compile(value) do
      {:ok, value}
    else
      _ -> {:error, :invalid_regex}
    end
  end

  defp parse_typed_value(field, _operator, token) do
    case field_type(field) do
      :string -> parse_string_literal(token)
      :decimal -> parse_decimal_literal(token)
      :date -> parse_date_literal(token)
    end
  end

  defp parse_string_literal("\"" <> _ = token) do
    value =
      token
      |> String.trim_leading("\"")
      |> String.trim_trailing("\"")
      |> String.replace("\\\"", "\"")
      |> String.replace("\\\\", "\\")

    {:ok, value}
  end

  defp parse_string_literal(_token), do: {:error, :invalid_expression}

  defp parse_decimal_literal(token) do
    case Decimal.cast(token) do
      {:ok, decimal} -> {:ok, decimal}
      :error -> {:error, :invalid_expression}
    end
  end

  defp parse_date_literal(token) do
    case Date.from_iso8601(token) do
      {:ok, date} -> {:ok, date}
      {:error, _reason} -> {:error, :invalid_expression}
    end
  end
end
