defmodule AurumFinance.Currency do
  @moduledoc """
  Currency defaults and country-to-currency lookup helpers.

  The default lookup is intentionally country-based and uses an inverted mapping
  of ISO 4217 currency code to ISO 3166-1 alpha-2 country codes.

  ## Examples

      iex> AurumFinance.Currency.default_code_for_country("BR")
      "BRL"

      iex> AurumFinance.Currency.default_code_for_country("cl")
      "CLP"

      iex> AurumFinance.Currency.default_code_for_country(nil)
      "USD"
  """

  @country_codes_by_currency %{
    "AED" => ["AE"],
    "AFN" => ["AF"],
    "ALL" => ["AL"],
    "AMD" => ["AM"],
    "AOA" => ["AO"],
    "ARS" => ["AR"],
    "AUD" => ["AU", "KI", "NR", "TV"],
    "AZN" => ["AZ"],
    "BAM" => ["BA"],
    "BBD" => ["BB"],
    "BDT" => ["BD"],
    "BGN" => ["BG"],
    "BHD" => ["BH"],
    "BIF" => ["BI"],
    "BND" => ["BN"],
    "BOB" => ["BO"],
    "BRL" => ["BR"],
    "BSD" => ["BS"],
    "BTN" => ["BT"],
    "BWP" => ["BW"],
    "BYN" => ["BY"],
    "BZD" => ["BZ"],
    "CAD" => ["CA"],
    "CHF" => ["CH", "LI"],
    "CLP" => ["CL"],
    "CNY" => ["CN"],
    "COP" => ["CO"],
    "CRC" => ["CR"],
    "CUP" => ["CU"],
    "CVE" => ["CV"],
    "CZK" => ["CZ"],
    "DJF" => ["DJ"],
    "DKK" => ["DK"],
    "DOP" => ["DO"],
    "DZD" => ["DZ"],
    "EGP" => ["EG"],
    "ERN" => ["ER"],
    "ETB" => ["ET"],
    "EUR" => [
      "AD",
      "AT",
      "BE",
      "CY",
      "DE",
      "EE",
      "ES",
      "FI",
      "FR",
      "GR",
      "HR",
      "IE",
      "IT",
      "LT",
      "LU",
      "LV",
      "MC",
      "ME",
      "MT",
      "NL",
      "PT",
      "SI",
      "SK",
      "SM",
      "VA"
    ],
    "FJD" => ["FJ"],
    "GBP" => ["GB"],
    "GEL" => ["GE"],
    "GHS" => ["GH"],
    "GMD" => ["GM"],
    "GNF" => ["GN"],
    "GTQ" => ["GT"],
    "GYD" => ["GY"],
    "HTG" => ["HT"],
    "HNL" => ["HN"],
    "HUF" => ["HU"],
    "IDR" => ["ID"],
    "ILS" => ["IL"],
    "INR" => ["IN"],
    "IQD" => ["IQ"],
    "IRR" => ["IR"],
    "ISK" => ["IS"],
    "JMD" => ["JM"],
    "JOD" => ["JO"],
    "JPY" => ["JP"],
    "KES" => ["KE"],
    "KHR" => ["KH"],
    "KMF" => ["KM"],
    "KGS" => ["KG"],
    "KPW" => ["KP"],
    "KRW" => ["KR"],
    "KWD" => ["KW"],
    "KZT" => ["KZ"],
    "LAK" => ["LA"],
    "LBP" => ["LB"],
    "LKR" => ["LK"],
    "LRD" => ["LR"],
    "LSL" => ["LS"],
    "LYD" => ["LY"],
    "MAD" => ["MA"],
    "MDL" => ["MD"],
    "MGA" => ["MG"],
    "MKD" => ["MK"],
    "MMK" => ["MM"],
    "MNT" => ["MN"],
    "MRO" => [],
    "MRU" => ["MR"],
    "MUR" => ["MU"],
    "MVR" => ["MV"],
    "MWK" => ["MW"],
    "MXN" => ["MX"],
    "MYR" => ["MY"],
    "MZN" => ["MZ"],
    "NAD" => ["NA"],
    "NGN" => ["NG"],
    "NIO" => ["NI"],
    "NOK" => ["NO"],
    "NPR" => ["NP"],
    "NZD" => ["NZ"],
    "OMR" => ["OM"],
    "PAB" => ["PA"],
    "PEN" => ["PE"],
    "PGK" => ["PG"],
    "PHP" => ["PH"],
    "PKR" => ["PK"],
    "PLN" => ["PL"],
    "PYG" => ["PY"],
    "QAR" => ["QA"],
    "RON" => ["RO"],
    "RSD" => ["RS"],
    "RUB" => ["RU"],
    "RWF" => ["RW"],
    "SAR" => ["SA"],
    "SBD" => ["SB"],
    "SCR" => ["SC"],
    "SDG" => ["SD"],
    "SEK" => ["SE"],
    "SGD" => ["SG"],
    "SLE" => ["SL"],
    "SOS" => ["SO"],
    "SRD" => ["SR"],
    "SSP" => ["SS"],
    "STN" => ["ST"],
    "SYP" => ["SY"],
    "SZL" => ["SZ"],
    "THB" => ["TH"],
    "TJS" => ["TJ"],
    "TMT" => ["TM"],
    "TND" => ["TN"],
    "TOP" => ["TO"],
    "TRY" => ["TR"],
    "TTD" => ["TT"],
    "TWD" => ["TW"],
    "TZS" => ["TZ"],
    "UAH" => ["UA"],
    "UGX" => ["UG"],
    "USD" => ["EC", "FM", "MH", "PW", "SV", "TL", "US", "ZW"],
    "UYU" => ["UY"],
    "UZS" => ["UZ"],
    "VES" => ["VE"],
    "VND" => ["VN"],
    "VUV" => ["VU"],
    "WST" => ["WS"],
    "XAF" => ["CF", "CG", "CM", "GA", "GQ", "TD"],
    "XCD" => ["AG", "DM", "GD", "KN", "LC", "VC"],
    "XOF" => ["BF", "BJ", "GW", "ML", "NE", "SN", "TG"],
    "YER" => ["YE"],
    "ZAR" => ["ZA"],
    "ZMW" => ["ZM"]
  }

  @currency_names %{
    "AED" => "UAE Dirham",
    "AFN" => "Afghan Afghani",
    "ALL" => "Albanian Lek",
    "AMD" => "Armenian Dram",
    "AOA" => "Angolan Kwanza",
    "ARS" => "Argentine Peso",
    "AUD" => "Australian Dollar",
    "AZN" => "Azerbaijani Manat",
    "BAM" => "Bosnia and Herzegovina Convertible Mark",
    "BBD" => "Barbadian Dollar",
    "BDT" => "Bangladeshi Taka",
    "BGN" => "Bulgarian Lev",
    "BHD" => "Bahraini Dinar",
    "BIF" => "Burundian Franc",
    "BND" => "Brunei Dollar",
    "BOB" => "Bolivian Boliviano",
    "BRL" => "Brazilian Real",
    "BSD" => "Bahamian Dollar",
    "BTN" => "Bhutanese Ngultrum",
    "BWP" => "Botswana Pula",
    "BYN" => "Belarusian Ruble",
    "BZD" => "Belize Dollar",
    "CAD" => "Canadian Dollar",
    "CHF" => "Swiss Franc",
    "CLP" => "Chilean Peso",
    "CNY" => "Chinese Yuan",
    "COP" => "Colombian Peso",
    "CRC" => "Costa Rican Colon",
    "CUP" => "Cuban Peso",
    "CVE" => "Cape Verdean Escudo",
    "CZK" => "Czech Koruna",
    "DJF" => "Djiboutian Franc",
    "DKK" => "Danish Krone",
    "DOP" => "Dominican Peso",
    "DZD" => "Algerian Dinar",
    "EGP" => "Egyptian Pound",
    "ERN" => "Eritrean Nakfa",
    "ETB" => "Ethiopian Birr",
    "EUR" => "Euro",
    "FJD" => "Fijian Dollar",
    "GBP" => "British Pound",
    "GEL" => "Georgian Lari",
    "GHS" => "Ghanaian Cedi",
    "GMD" => "Gambian Dalasi",
    "GNF" => "Guinean Franc",
    "GTQ" => "Guatemalan Quetzal",
    "GYD" => "Guyanese Dollar",
    "HTG" => "Haitian Gourde",
    "HNL" => "Honduran Lempira",
    "HUF" => "Hungarian Forint",
    "IDR" => "Indonesian Rupiah",
    "ILS" => "Israeli New Shekel",
    "INR" => "Indian Rupee",
    "IQD" => "Iraqi Dinar",
    "IRR" => "Iranian Rial",
    "ISK" => "Icelandic Krona",
    "JMD" => "Jamaican Dollar",
    "JOD" => "Jordanian Dinar",
    "JPY" => "Japanese Yen",
    "KES" => "Kenyan Shilling",
    "KHR" => "Cambodian Riel",
    "KMF" => "Comorian Franc",
    "KGS" => "Kyrgyzstani Som",
    "KPW" => "North Korean Won",
    "KRW" => "South Korean Won",
    "KWD" => "Kuwaiti Dinar",
    "KZT" => "Kazakhstani Tenge",
    "LAK" => "Lao Kip",
    "LBP" => "Lebanese Pound",
    "LKR" => "Sri Lankan Rupee",
    "LRD" => "Liberian Dollar",
    "LSL" => "Lesotho Loti",
    "LYD" => "Libyan Dinar",
    "MAD" => "Moroccan Dirham",
    "MDL" => "Moldovan Leu",
    "MGA" => "Malagasy Ariary",
    "MKD" => "Macedonian Denar",
    "MMK" => "Myanmar Kyat",
    "MNT" => "Mongolian Tugrik",
    "MRO" => "Mauritanian Ouguiya (legacy)",
    "MRU" => "Mauritanian Ouguiya",
    "MUR" => "Mauritian Rupee",
    "MVR" => "Maldivian Rufiyaa",
    "MWK" => "Malawian Kwacha",
    "MXN" => "Mexican Peso",
    "MYR" => "Malaysian Ringgit",
    "MZN" => "Mozambican Metical",
    "NAD" => "Namibian Dollar",
    "NGN" => "Nigerian Naira",
    "NIO" => "Nicaraguan Cordoba",
    "NOK" => "Norwegian Krone",
    "NPR" => "Nepalese Rupee",
    "NZD" => "New Zealand Dollar",
    "OMR" => "Omani Rial",
    "PAB" => "Panamanian Balboa",
    "PEN" => "Peruvian Sol",
    "PGK" => "Papua New Guinean Kina",
    "PHP" => "Philippine Peso",
    "PKR" => "Pakistani Rupee",
    "PLN" => "Polish Zloty",
    "PYG" => "Paraguayan Guarani",
    "QAR" => "Qatari Riyal",
    "RON" => "Romanian Leu",
    "RSD" => "Serbian Dinar",
    "RUB" => "Russian Ruble",
    "RWF" => "Rwandan Franc",
    "SAR" => "Saudi Riyal",
    "SBD" => "Solomon Islands Dollar",
    "SCR" => "Seychellois Rupee",
    "SDG" => "Sudanese Pound",
    "SEK" => "Swedish Krona",
    "SGD" => "Singapore Dollar",
    "SLE" => "Sierra Leonean Leone",
    "SOS" => "Somali Shilling",
    "SRD" => "Surinamese Dollar",
    "SSP" => "South Sudanese Pound",
    "STN" => "Sao Tome and Principe Dobra",
    "SYP" => "Syrian Pound",
    "SZL" => "Swazi Lilangeni",
    "THB" => "Thai Baht",
    "TJS" => "Tajikistani Somoni",
    "TMT" => "Turkmenistani Manat",
    "TND" => "Tunisian Dinar",
    "TOP" => "Tongan Pa'anga",
    "TRY" => "Turkish Lira",
    "TTD" => "Trinidad and Tobago Dollar",
    "TWD" => "New Taiwan Dollar",
    "TZS" => "Tanzanian Shilling",
    "UAH" => "Ukrainian Hryvnia",
    "UGX" => "Ugandan Shilling",
    "USD" => "US Dollar",
    "UYU" => "Uruguayan Peso",
    "UZS" => "Uzbekistani Som",
    "VES" => "Venezuelan Bolivar",
    "VND" => "Vietnamese Dong",
    "VUV" => "Vanuatu Vatu",
    "WST" => "Samoan Tala",
    "XAF" => "Central African CFA Franc",
    "XCD" => "East Caribbean Dollar",
    "XOF" => "West African CFA Franc",
    "YER" => "Yemeni Rial",
    "ZAR" => "South African Rand",
    "ZMW" => "Zambian Kwacha"
  }

  # Generate one function clause per country at compile time so runtime lookup
  # is just pattern matching on the normalized ISO 3166-1 alpha-2 code.
  for {currency_code, country_codes} <- @country_codes_by_currency,
      country_code <- country_codes do
    defp default_code_for_normalized_country(unquote(country_code)), do: unquote(currency_code)
  end

  defp default_code_for_normalized_country(_country_code), do: "USD"

  @doc """
  Returns the default ISO 4217 currency code for a country code.

  ## Examples

      iex> AurumFinance.Currency.default_code_for_country("BR")
      "BRL"

      iex> AurumFinance.Currency.default_code_for_country("de")
      "EUR"

      iex> AurumFinance.Currency.default_code_for_country(nil)
      "USD"
  """
  @spec default_code_for_country(String.t() | nil) :: String.t()
  def default_code_for_country(country_code) when is_binary(country_code) do
    country_code
    |> String.trim()
    |> String.upcase()
    |> default_code_for_normalized_country()
  end

  def default_code_for_country(_country_code), do: "USD"

  @doc """
  Returns currency options suitable for select inputs.

  ## Examples

      iex> {"USD - US Dollar", "USD"} in AurumFinance.Currency.options()
      true

      iex> {"BRL - Brazilian Real", "BRL"} in AurumFinance.Currency.options()
      true
  """
  @spec options() :: [{String.t(), String.t()}]
  def options do
    @country_codes_by_currency
    |> Map.keys()
    |> Enum.sort()
    |> Enum.map(&{"#{&1} - #{Map.get(@currency_names, &1, &1)}", &1})
  end
end
