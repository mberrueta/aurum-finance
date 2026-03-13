defmodule AurumFinance.Classification.ExpressionEvaluator do
  @moduledoc """
  Behaviour boundary between the AurumFinance rules DSL and a runtime evaluator.

  The compiler and validator own the persisted DSL format. A concrete evaluator
  backend can later compile the validated AST and execute it against transaction
  facts without changing the public Classification API.
  """

  @type field ::
          :description
          | :amount
          | :abs_amount
          | :currency_code
          | :date
          | :source_type
          | :account_name
          | :account_type
          | :institution_name

  @type operator ::
          :equals
          | :contains
          | :starts_with
          | :ends_with
          | :matches_regex
          | :greater_than
          | :less_than
          | :greater_than_or_equal
          | :less_than_or_equal
          | :is_empty
          | :is_not_empty

  @type literal :: String.t() | Decimal.t() | Date.t() | nil
  @type condition_ast :: {:condition, field(), operator(), literal()}
  @type expression_ast :: condition_ast() | {:not, expression_ast()} | {:and, [expression_ast()]}

  @callback compile(expression_ast()) :: {:ok, term()} | {:error, term()}
  @callback evaluate(term(), map()) :: {:ok, boolean()} | {:error, term()}
end
