defmodule AurumFinance.Gettext do
  @moduledoc """
  Core Gettext backend for translations shared across domain and web layers.
  """

  use Gettext.Backend, otp_app: :aurum_finance
end
