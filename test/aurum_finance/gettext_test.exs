defmodule AurumFinance.GettextTest do
  use ExUnit.Case, async: true

  describe "dgettext/3" do
    test "shared translations resolve through the single backend" do
      assert Gettext.dgettext(AurumFinance.Gettext, "errors", "error_field_required") ==
               "This field is required."
    end
  end
end
