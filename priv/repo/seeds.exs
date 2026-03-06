alias AurumFinance.Entities.Entity
alias AurumFinance.Repo

now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

default_entities = [
  %{
    name: "Personal",
    type: :individual,
    country_code: "US",
    fiscal_residency_country_code: "US",
    default_tax_rate_type: "irs_official",
    notes: "Default personal books"
  },
  %{
    name: "Main LLC",
    type: :legal_entity,
    country_code: "US",
    fiscal_residency_country_code: "US",
    default_tax_rate_type: "irs_official",
    notes: "Primary legal entity"
  },
  %{
    name: "Family Trust",
    type: :trust,
    country_code: "US",
    fiscal_residency_country_code: "US",
    default_tax_rate_type: "irs_official",
    notes: "Trust ownership boundary"
  }
]

Enum.each(default_entities, fn attrs ->
  case Repo.get_by(Entity, name: attrs.name) do
    nil ->
      attrs
      |> Map.put(:inserted_at, now)
      |> Map.put(:updated_at, now)
      |> then(&Entity.changeset(%Entity{}, &1))
      |> Repo.insert!()

      IO.puts("seeded entity: #{attrs.name}")

    _entity ->
      IO.puts("entity already exists, skipping: #{attrs.name}")
  end
end)
