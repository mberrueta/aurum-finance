defmodule AurumFinance.Entities.Country do
  @moduledoc """
  Country catalog and country-based defaults used by Entities forms and changesets.
  """

  @countries [
    {"Afghanistan", "AF"},
    {"Albania", "AL"},
    {"Algeria", "DZ"},
    {"Andorra", "AD"},
    {"Angola", "AO"},
    {"Antigua and Barbuda", "AG"},
    {"Argentina", "AR"},
    {"Armenia", "AM"},
    {"Australia", "AU"},
    {"Austria", "AT"},
    {"Azerbaijan", "AZ"},
    {"Bahamas", "BS"},
    {"Bahrain", "BH"},
    {"Bangladesh", "BD"},
    {"Barbados", "BB"},
    {"Belarus", "BY"},
    {"Belgium", "BE"},
    {"Belize", "BZ"},
    {"Benin", "BJ"},
    {"Bhutan", "BT"},
    {"Bolivia", "BO"},
    {"Bosnia and Herzegovina", "BA"},
    {"Botswana", "BW"},
    {"Brazil", "BR"},
    {"Brunei", "BN"},
    {"Bulgaria", "BG"},
    {"Burkina Faso", "BF"},
    {"Burundi", "BI"},
    {"Cabo Verde", "CV"},
    {"Cambodia", "KH"},
    {"Cameroon", "CM"},
    {"Canada", "CA"},
    {"Central African Republic", "CF"},
    {"Chad", "TD"},
    {"Chile", "CL"},
    {"China", "CN"},
    {"Colombia", "CO"},
    {"Comoros", "KM"},
    {"Congo", "CG"},
    {"Costa Rica", "CR"},
    {"Croatia", "HR"},
    {"Cuba", "CU"},
    {"Cyprus", "CY"},
    {"Czechia", "CZ"},
    {"Denmark", "DK"},
    {"Djibouti", "DJ"},
    {"Dominica", "DM"},
    {"Dominican Republic", "DO"},
    {"Ecuador", "EC"},
    {"Egypt", "EG"},
    {"El Salvador", "SV"},
    {"Equatorial Guinea", "GQ"},
    {"Eritrea", "ER"},
    {"Estonia", "EE"},
    {"Eswatini", "SZ"},
    {"Ethiopia", "ET"},
    {"Fiji", "FJ"},
    {"Finland", "FI"},
    {"France", "FR"},
    {"Gabon", "GA"},
    {"Gambia", "GM"},
    {"Georgia", "GE"},
    {"Germany", "DE"},
    {"Ghana", "GH"},
    {"Greece", "GR"},
    {"Grenada", "GD"},
    {"Guatemala", "GT"},
    {"Guinea", "GN"},
    {"Guinea-Bissau", "GW"},
    {"Guyana", "GY"},
    {"Haiti", "HT"},
    {"Honduras", "HN"},
    {"Hungary", "HU"},
    {"Iceland", "IS"},
    {"India", "IN"},
    {"Indonesia", "ID"},
    {"Iran", "IR"},
    {"Iraq", "IQ"},
    {"Ireland", "IE"},
    {"Israel", "IL"},
    {"Italy", "IT"},
    {"Jamaica", "JM"},
    {"Japan", "JP"},
    {"Jordan", "JO"},
    {"Kazakhstan", "KZ"},
    {"Kenya", "KE"},
    {"Kiribati", "KI"},
    {"Kuwait", "KW"},
    {"Kyrgyzstan", "KG"},
    {"Laos", "LA"},
    {"Latvia", "LV"},
    {"Lebanon", "LB"},
    {"Lesotho", "LS"},
    {"Liberia", "LR"},
    {"Libya", "LY"},
    {"Liechtenstein", "LI"},
    {"Lithuania", "LT"},
    {"Luxembourg", "LU"},
    {"Madagascar", "MG"},
    {"Malawi", "MW"},
    {"Malaysia", "MY"},
    {"Maldives", "MV"},
    {"Mali", "ML"},
    {"Malta", "MT"},
    {"Marshall Islands", "MH"},
    {"Mauritania", "MR"},
    {"Mauritius", "MU"},
    {"Mexico", "MX"},
    {"Micronesia", "FM"},
    {"Moldova", "MD"},
    {"Monaco", "MC"},
    {"Mongolia", "MN"},
    {"Montenegro", "ME"},
    {"Morocco", "MA"},
    {"Mozambique", "MZ"},
    {"Myanmar", "MM"},
    {"Namibia", "NA"},
    {"Nauru", "NR"},
    {"Nepal", "NP"},
    {"Netherlands", "NL"},
    {"New Zealand", "NZ"},
    {"Nicaragua", "NI"},
    {"Niger", "NE"},
    {"Nigeria", "NG"},
    {"North Korea", "KP"},
    {"North Macedonia", "MK"},
    {"Norway", "NO"},
    {"Oman", "OM"},
    {"Pakistan", "PK"},
    {"Palau", "PW"},
    {"Panama", "PA"},
    {"Papua New Guinea", "PG"},
    {"Paraguay", "PY"},
    {"Peru", "PE"},
    {"Philippines", "PH"},
    {"Poland", "PL"},
    {"Portugal", "PT"},
    {"Qatar", "QA"},
    {"Romania", "RO"},
    {"Russia", "RU"},
    {"Rwanda", "RW"},
    {"Saint Kitts and Nevis", "KN"},
    {"Saint Lucia", "LC"},
    {"Saint Vincent and the Grenadines", "VC"},
    {"Samoa", "WS"},
    {"San Marino", "SM"},
    {"Sao Tome and Principe", "ST"},
    {"Saudi Arabia", "SA"},
    {"Senegal", "SN"},
    {"Serbia", "RS"},
    {"Seychelles", "SC"},
    {"Sierra Leone", "SL"},
    {"Singapore", "SG"},
    {"Slovakia", "SK"},
    {"Slovenia", "SI"},
    {"Solomon Islands", "SB"},
    {"Somalia", "SO"},
    {"South Africa", "ZA"},
    {"South Korea", "KR"},
    {"South Sudan", "SS"},
    {"Spain", "ES"},
    {"Sri Lanka", "LK"},
    {"Sudan", "SD"},
    {"Suriname", "SR"},
    {"Sweden", "SE"},
    {"Switzerland", "CH"},
    {"Syria", "SY"},
    {"Taiwan", "TW"},
    {"Tajikistan", "TJ"},
    {"Tanzania", "TZ"},
    {"Thailand", "TH"},
    {"Timor-Leste", "TL"},
    {"Togo", "TG"},
    {"Tonga", "TO"},
    {"Trinidad and Tobago", "TT"},
    {"Tunisia", "TN"},
    {"Turkey", "TR"},
    {"Turkmenistan", "TM"},
    {"Tuvalu", "TV"},
    {"Uganda", "UG"},
    {"Ukraine", "UA"},
    {"United Arab Emirates", "AE"},
    {"United Kingdom", "GB"},
    {"United States", "US"},
    {"Uruguay", "UY"},
    {"Uzbekistan", "UZ"},
    {"Vanuatu", "VU"},
    {"Vatican City", "VA"},
    {"Venezuela", "VE"},
    {"Vietnam", "VN"},
    {"Yemen", "YE"},
    {"Zambia", "ZM"},
    {"Zimbabwe", "ZW"}
  ]

  @tax_rate_type_by_country %{
    "AR" => "afip_official",
    "BR" => "receita_federal_official",
    "CL" => "sii_official",
    "PE" => "sunat_official",
    "UY" => "bcu_official",
    "US" => "irs_official"
  }
  @tax_rate_suffixes ["market_close", "tax_specific", "bank_settlement"]

  @country_codes MapSet.new(Enum.map(@countries, fn {_name, code} -> code end))

  @spec options() :: [{String.t(), String.t()}]
  def options, do: @countries

  @spec default_tax_rate_type(String.t() | nil) :: String.t() | nil
  def default_tax_rate_type(nil), do: nil

  def default_tax_rate_type(country_code) when is_binary(country_code) do
    normalized_country_code = String.upcase(country_code)

    cond do
      Map.has_key?(@tax_rate_type_by_country, normalized_country_code) ->
        Map.fetch!(@tax_rate_type_by_country, normalized_country_code)

      MapSet.member?(@country_codes, normalized_country_code) ->
        "#{String.downcase(normalized_country_code)}_official"

      true ->
        nil
    end
  end

  @doc """
  Returns suggested tax rate types for a country code.
  """
  @spec tax_rate_type_options(String.t() | nil) :: [String.t()]
  def tax_rate_type_options(nil), do: []

  def tax_rate_type_options(country_code) when is_binary(country_code) do
    normalized_country_code = String.upcase(country_code)

    if MapSet.member?(@country_codes, normalized_country_code) do
      default = default_tax_rate_type(normalized_country_code)

      prefixed =
        Enum.map(@tax_rate_suffixes, &"#{String.downcase(normalized_country_code)}_#{&1}")

      Enum.uniq([default | prefixed]) |> Enum.reject(&is_nil/1)
    else
      []
    end
  end
end
