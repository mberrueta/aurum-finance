
# AurumFinance — Testing Guidelines (ExUnit, Ecto, LiveView)

> Fast, isolated, descriptive. Prefer pattern‑matching assertions and explicit failure cases.

## 0) Test Types
- **Unit**: pure modules, no DB.
- **DataCase**: DB‑backed contexts/schemas (uses SQL Sandbox).
- **ConnCase**: HTTP controllers/plugs.
- **LiveViewCase**: LiveView interactions, HEEx rendering.
- **Integration**: happy‑path flows across layers.

## 1) Structure & Naming
- One `describe` per function/behavior; meaningful test names.
- Use factories as the default test-data mechanism; avoid `*_fixture` helpers and fixture-style naming in tests.
- Never seed data with raw SQL in tests.

```elixir
# test/aurum_finance/medical_test.exs
defmodule AurumFinance.MedicalTest do
  use AurumFinance.DataCase, async: true
  import AurumFinance.Factory

  describe "link_doctor_patient/2" do
    test "links successfully" do
      doctor = insert(:doctor)
      patient = insert(:patient)

      assert {:ok, link} = Medical.link_doctor_patient(doctor, patient)
      assert link.doctor_id == doctor.id
      assert link.patient_id == patient.id
    end

    test "returns changeset error on duplicate" do
      doctor = insert(:doctor)
      patient = insert(:patient)
      insert(:doctor_patient, doctor: doctor, patient: patient)

      assert {:error, %Ecto.Changeset{}} = Medical.link_doctor_patient(doctor, patient)
    end
  end
end
```

## 2) ExMachina Factories
- Centralize valid attrs; override per test.
- Prefer `build/2` + `insert/2` over hand‑built structs.
- If a context API must be used to create a record, wrap that in a narrowly named helper that still starts from factory-backed entities/accounts instead of introducing fixture terminology.

```elixir
# test/support/factory.ex
factory :doctor do
  name { sequence(:name, &"Dra. #{&1}") }
  specialty { "Angiologista" }
end
```

## 3) Pattern‑Matching Assertions
- Assert on typed tuples and struct fields.
- Avoid string contains for behavior validation.

```elixir
assert {:ok, %Doctor{id: id}} = Medical.create_doctor(params)
refute is_nil(id)
```

## 4) LiveView Tests
- Use `live(conn, ~p"/path")`, `element/2`, `render_click/1`, `render_change/1`.
- Assert navigation with `assert_patch`/`assert_redirect`.
- **No literal Portuguese**: assert with Gettext‑produced strings.

```elixir
use AurumFinanceWeb.ConnCase
import AurumFinanceWeb.Gettext

setup :register_and_log_in_user

test "invites patient" do
  {:ok, view, _html} = live(conn, ~p"/doctor/invite")
  view
  |> form("#invite-form", %{email: "a@b.com"})
  |> render_submit()

  assert view |> has_element?("[role=alert]", gettext("doctor_portal", ".invite_sent"))
end
```

## 5) HTTP & External Services
- Use **Bypass** for HTTP servers.
- Use **Mox** for behaviors (declare `@behaviour` in client).

```elixir
# Bypass
setup do
  bypass = Bypass.open()
  Application.put_env(:aurum_finance, :http_base, "http://localhost:#{bypass.port}")
  {:ok, bypass: bypass}
end

test "decodes json", %{bypass: bypass} do
  Bypass.expect(bypass, fn conn -> Plug.Conn.resp(conn, 200, ~s({"ok":true})) end)
  assert {:ok, %{"ok" => true}} = MyClient.get("/ping")
end

# Mox
setup :verify_on_exit!

test "sends sms via behaviour" do
  SmsMock
  |> expect(:send, fn _to, _msg -> :ok end)
  assert :ok = Notifier.send_sms("555", "Oi")
end
```

## 6) Sandbox, Concurrency & Timing
- `DataCase` defaults to SQL Sandbox; set `async: true` when possible.
- Avoid `Process.sleep/1`; use `assert_receive` with timeouts.

```elixir
send(self(), {:done, 1})
assert_receive {:done, 1}, 50
```

## 7) Test Helpers
- Put helpers in `test/support/*.ex` and `doctest` public modules when meaningful.
- If asserting HTML, use **Floki** selectors and roles/labels rather than class names.

```elixir
import Floki, only: [find: 2, text: 1]
html = render(view)
assert html |> find("[role=heading]") |> text() =~ "Dra."
```

## 8) CI Expectations
- Keep tests fast (< 5s ideally for unit).
- No external network. No sleeps > 50ms.
- Coverage goal: pragmatic; prefer meaningful tests over %.

---
