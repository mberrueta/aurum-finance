defmodule AurumFinanceWeb.PageController do
  use AurumFinanceWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
