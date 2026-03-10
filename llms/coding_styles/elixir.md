# AurumFinance — Elixir & Phoenix (LiveView) Guidelines

> Minimal, idiomatic, maintainable. UI strings in pt‑BR via Gettext; everything else in English.

## 0) Scope & Goals
- Prefer small, pure functions; explicit typed returns (`{:ok, t} | {:error, reason}`).
- Encapsulate DB and side‑effects in context boundaries.
- LiveView first: components, assigns hygiene, i18n, a11y.
- Keep diffs minimal; remove dead/experimental code before merge.

## 1) Project Structure & Modules
- **Contexts** expose stable public APIs (`YourApp.Accounts.*`, `YourApp.Medical.*`).
- **Schemas** live under their context (not a global `Schemas` bucket).
- **Web** layer only depends on contexts, not vice‑versa.
- Module names: `AurumFinanceWeb.*` (web), `AurumFinance.*` (core). One module per file.

```elixir
# good
defmodule AurumFinance.Medical do
  alias AurumFinance.Repo
  alias AurumFinance.Medical.{Doctor, Patient}

  @spec link_doctor_patient(Doctor.t(), Patient.t()) :: {:ok, map} | {:error, Ecto.Changeset.t()}
  def link_doctor_patient(%Doctor{} = d, %Patient{} = p) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:link, DoctorPatient.changeset(%DoctorPatient{}, %{doctor_id: d.id, patient_id: p.id}))
    |> Repo.transaction()
    |> case do
      {:ok, %{link: link}} -> {:ok, link}
      {:error, :link, changeset, _} -> {:error, changeset}
    end
  end
end
```

## 2) Code Style
- `alias/require/import/use` grouped and alphabetized; one alias per line.
- Add `@moduledoc false` only for trivial modules; otherwise write a short `@moduledoc`.
- Document public functions with `@doc` and typespecs (`@spec`) when behavior is non‑trivial.
- Pipe for data transformation only. Do **not** pipe into `case`/`with`; return tuples and branch at the end.
- Prefer pattern matching through function heads and small helpers before reaching for `case`, `if`, or `cond`.
- Avoid `case` branches with only two simple outcomes when pattern matching in separate clauses keeps the flow flatter.
- Prefer `with` for linear happy-path flows that would otherwise become nested branching.
- When the same value moves through a linear sequence of transformations, prefer pipes over temporary rebinding.

```elixir
# good
def create_and_notify(attrs) do
  with {:ok, entity} <- create_entity(attrs),
       :ok <- notify(entity) do
    {:ok, entity}
  end
end

# prefer handle at the end, no deep nesting
case create_and_notify(attrs) do
  {:ok, e} -> {:ok, e}
  {:error, reason} -> {:error, reason}
end

# good
def claim_import(imported_file) do
  imported_file
  |> get_imported_file_for_update!()
  |> claim_locked_import()
end

defp put_default_currency(%{currency: _} = canonical_data, _opts), do: canonical_data

defp put_default_currency(canonical_data, opts) do
  canonical_data
  |> default_currency_from_opts(opts)
  |> maybe_put_currency(canonical_data)
end

defp maybe_put_currency(nil, canonical_data), do: canonical_data
defp maybe_put_currency(currency, canonical_data), do: Map.put(canonical_data, :currency, currency)
```

## 3) Error Handling
- Return tuples; reserve `raise` for programmer errors or non‑recoverable boundaries (startup, mix tasks).
- Normalize external errors to domain atoms/structs before bubbling up.
- Never swallow errors; attach context in logs with metadata.

```elixir
with {:ok, resp} <- Http.get(url),
     {:ok, data} <- Jason.decode(resp.body) do
  {:ok, data}
else
  {:error, %HTTPoison.Error{reason: r}} -> {:error, {:http_error, r}}
  {:error, %Jason.DecodeError{} = e} -> {:error, {:invalid_json, e.position}}
end
```

## 4) Ecto
- Use `changeset/2` for validation; use `unique_constraint/3` instead of prechecks.
- Prefer `Ecto.Multi` for multi‑step writes; return final typed tuples.
- Keep queries composable; expose filter functions rather than many `list_by_*` variants.
- Only preload what you render/use; avoid N+1 with explicit `preload`.

```elixir
# composable queries
import Ecto.Query

base = from d in Doctor

def with_specialty(q, spec), do: from d in q, where: d.specialty == ^spec

def list_doctors(filters) do
  q = base |> maybe(filters[:specialty], &with_specialty(&1, &2))
  Repo.all(q)
end

defp maybe(q, nil, _fun), do: q
defp maybe(q, v, fun), do: fun.(q, v)
```

## 5) Phoenix LiveView & HEEx
- Use **verified routes** (`~p"/path"`) and `push_navigate/2`.
- Set default assigns in `mount/3` (guard with `connected?/1` for side‑effects).
- Prefer **function components** with `attr/3` and `slot/3`; validate assigns.
- Use `:if`, `:for` and `{}` in HEEx; avoid raw `<% %>` when possible.
- Use `phx-update="stream|append|prepend|replace"` intentionally; default is diff‑friendly.
- All user‑facing text via Gettext (`dgettext("context", ".key")`). No literals.
- Follow basic a11y: labels, roles, keyboard support.

```elixir
# component
attr :doctor, AurumFinance.Medical.Doctor, required: true

def doctor_badge(assigns) do
  ~H"""
  <span class="inline-flex items-center gap-2 rounded-xl px-2 py-1 border">
    <%= @doctor.name %>
    <span class="text-xs text-slate-500"><%= @doctor.specialty %></span>
  </span>
  """
end
```

## 6) Internationalization (pt‑BR)
- Do **not** inline Portuguese strings. Always go through Gettext domains.
- Keys prefix with a dot inside templates/components: `dgettext("doctor_portal", ".invite_client")`.
- Interpolations must be named: `dgettext("common", ".hello_user", name: user.name)`.

## 7) Logging & Telemetry
- Use `Logger` macros with metadata (`request_id`, `user_id`, `module`).
- Avoid logging PII (CPF, phone). Truncate payloads.
- Prefer Telemetry events for metrics; no ad‑hoc global counters.

```elixir
Logger.info("linked doctor to patient", doctor_id: d.id, patient_id: p.id)
:telemetry.execute([:aurum_finance, :link, :complete], %{count: 1}, %{doctor_id: d.id})
```

## 8) Config & Secrets
- Runtime config in `config/runtime.exs`; no secrets in repo.
- Avoid compile‑time app URLs; use env/ENV vars.
- Feature flags via config or DB table (not module attributes).

## 9) Credo, Formatter, Security
- Enforce `mix format` (no diffs on CI).
- Credo: enable `Consistency`, `Readability`, `Refactoring`, `Warning` checks.
- Sobelow for security; fix or mark false positives with comments.

```sh
mix format --check-formatted
mix credo --strict
mix sobelow --exit
```

## 10) Performance
- Batch queries; prefer `Repo.insert_all` for bulk inserts when validations are elsewhere.
- ETS/caches only with eviction strategy; document TTL.
- Avoid `Enum.map` over large lists when DB can filter/aggregate.

---
