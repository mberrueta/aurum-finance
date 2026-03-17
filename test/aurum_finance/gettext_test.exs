defmodule AurumFinance.GettextTest do
  use ExUnit.Case, async: true

  describe "dgettext/3" do
    test "core backend matches the web backend for shared translations" do
      assert Gettext.dgettext(AurumFinance.Gettext, "errors", "error_field_required") ==
               Gettext.dgettext(AurumFinanceWeb.Gettext, "errors", "error_field_required")
    end
  end
end
