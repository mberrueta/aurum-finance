defmodule AurumFinanceWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use AurumFinanceWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint AurumFinanceWeb.Endpoint

      use AurumFinanceWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import AurumFinanceWeb.ConnCase
    end
  end

  def log_in_root(conn) do
    session = AurumFinance.Auth.put_authenticated_session(%{}, DateTime.utc_now())
    put_root_session(conn, session)
  end

  def put_root_session(conn, session) when is_map(session) do
    Enum.reduce(session, Phoenix.ConnTest.init_test_session(conn, %{}), fn {key, value},
                                                                           acc_conn ->
      Plug.Conn.put_session(acc_conn, key, value)
    end)
  end

  def put_root_session_timestamps(conn, auth_at_unix, last_seen_unix)
      when is_integer(auth_at_unix) and is_integer(last_seen_unix) do
    put_root_session(conn, %{
      "root_authenticated_at" => auth_at_unix,
      "root_last_seen_at" => last_seen_unix
    })
  end

  setup tags do
    AurumFinance.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
