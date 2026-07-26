defmodule AgentJido.Demos.DataPipeline.Pipeline do
  @moduledoc """
  Shared, deterministic data-pipeline logic for the ETL agent.

  Four real stages drive the pipeline:

  * `validate/1` checks each collected record against its source's schema and
    partitions the batch into valid records and rejected records with a reason.
  * `transform/1` applies deterministic per-source transforms -- currency
    normalization, derived amounts, canonical kinds -- and de-duplicates by
    source and id so a repeated pull does not double-count.
  * `load/1` "writes" the transformed batch to a destination and produces a
    stable checksum (`phash2` over a canonical projection) so two identical runs
    always agree.
  * `summarize/1` rolls the run up to one human-readable report.

  Used by the `ValidateRecords`, `TransformRecords`, `LoadRecords`, and
  `Summarize` actions and -- when an earlier step has not run -- derived lazily
  by `resolve/1` so each step is self-sufficient. No LLM, no network.
  """

  @doc """
  Validate a batch of collected records against each record's source schema.

  Each record must carry its `source`. Returns `{valid, rejected}`, where
  `rejected` is a list of `%{record:, reason:}` entries. An empty or unloaded
  batch validates to two empty lists.
  """
  @spec validate([map()]) :: {[map()], [%{record: map(), reason: String.t()}]}
  def validate(records) when is_list(records) do
    records
    |> Enum.reduce({[], []}, fn record, {valid, rejected} ->
      case check(record) do
        :ok -> {[record | valid], rejected}
        {:error, reason} -> {valid, [%{record: record, reason: reason} | rejected]}
      end
    end)
    |> then(fn {valid, rejected} -> {Enum.reverse(valid), Enum.reverse(rejected)} end)
  end

  # Per-source schema checks. Each returns :ok | {:error, reason} from the real
  # fields on the record, so a missing or malformed field is rejected for real.
  defp check(%{source: "orders"} = r) do
    cond do
      not is_integer(r[:id]) -> {:error, "orders record missing integer id"}
      blank?(r[:customer]) -> {:error, "orders record missing customer"}
      not (is_integer(r[:amount_cents]) and r[:amount_cents] >= 0) -> {:error, "orders record missing amount_cents"}
      true -> :ok
    end
  end

  defp check(%{source: "users"} = r) do
    cond do
      not is_integer(r[:id]) ->
        {:error, "users record missing integer id"}

      blank?(r[:email]) or not String.contains?(to_string(r[:email]), "@") ->
        {:error, "users record missing valid email"}

      blank?(r[:country]) ->
        {:error, "users record missing country"}

      true ->
        :ok
    end
  end

  defp check(%{source: "events"} = r) do
    cond do
      not is_integer(r[:id]) -> {:error, "events record missing integer id"}
      blank?(r[:event]) -> {:error, "events record missing event name"}
      not is_integer(r[:user_id]) -> {:error, "events record missing user_id"}
      true -> :ok
    end
  end

  defp check(%{source: source}) do
    {:error, "unknown source #{source}"}
  end

  defp check(_record) do
    {:error, "record missing source"}
  end

  @doc """
  Apply deterministic per-source transforms to a batch of valid records and
  de-duplicate by `{source, id}`, keeping the first occurrence. The batch is
  returned sorted by `{source, id}` so the output is stable across runs.
  """
  @spec transform([map()]) :: [map()]
  def transform(records) when is_list(records) do
    records
    |> Enum.map(&transform_one/1)
    |> dedupe_by_identity()
    |> Enum.sort_by(fn r -> {r[:source], r[:id]} end)
  end

  # orders: normalize currency to uppercase and derive a USD amount from cents.
  defp transform_one(%{source: "orders"} = r) do
    r
    |> Map.put(:currency, to_string(r[:currency]) |> String.upcase())
    |> Map.put(:amount_usd, r[:amount_cents] / 100)
  end

  # users: lowercase the email and uppercase the country for a canonical key.
  defp transform_one(%{source: "users"} = r) do
    r
    |> Map.put(:email, to_string(r[:email]) |> String.downcase())
    |> Map.put(:country, to_string(r[:country]) |> String.upcase())
  end

  # events: derive a canonical analytics kind from the raw event name.
  defp transform_one(%{source: "events"} = r) do
    Map.put(r, :kind, kind_of(to_string(r[:event])))
  end

  defp transform_one(record), do: record

  defp kind_of("page_view"), do: "view"
  defp kind_of("signup"), do: "account"
  defp kind_of("purchase"), do: "commerce"
  defp kind_of(other), do: other

  defp dedupe_by_identity(records) do
    records
    |> Enum.reduce({[], MapSet.new()}, fn record, {kept, seen} ->
      key = {record[:source], record[:id]}

      if MapSet.member?(seen, key) do
        {kept, seen}
      else
        {[record | kept], MapSet.put(seen, key)}
      end
    end)
    |> elem(0)
    |> Enum.reverse()
  end

  @doc """
  "Load" a transformed batch to the destination and produce a stable checksum.

  Returns `%{loaded_count:, destination_checksum:}`. The checksum is a
  deterministic `phash2` over a canonical projection (sorted source/id pairs
  plus the total order amount), so two identical runs always agree. An empty
  batch loads zero records and a stable empty checksum.
  """
  @spec load([map()]) :: %{loaded_count: non_neg_integer(), destination_checksum: String.t()}
  def load(records) when is_list(records) do
    total_cents =
      records
      |> Enum.filter(&(&1[:source] == "orders"))
      |> Enum.reduce(0, fn r, acc -> acc + (r[:amount_cents] || 0) end)

    identity =
      records
      |> Enum.map(fn r -> "#{r[:source]}:#{r[:id]}" end)
      |> Enum.sort()
      |> Enum.join(",")

    digest =
      [identity, "total_cents=#{total_cents}"]
      |> Enum.join("|")
      |> then(&:erlang.phash2(&1, 1_000_000_000))
      |> Integer.to_string()
      |> String.pad_leading(9, "0")

    %{loaded_count: length(records), destination_checksum: "dp-#{digest}"}
  end

  @doc """
  Build a one-line run report from a resolved pipeline state map. Expects the
  keys `sources_loaded`, `ingested`, `valid`, `rejected`, `transformed`, and the
  `load/1` result merged in (`loaded_count`, `destination_checksum`).
  """
  @spec summarize(map()) :: String.t()
  def summarize(state) do
    sources = state[:sources_loaded] |> List.wrap() |> Enum.sort() |> Enum.join(", ")
    sources_label = if sources == "", do: "none", else: sources

    "pipeline complete: sources [#{sources_label}] · ingested #{length(state[:ingested] || [])}" <>
      " · valid #{length(state[:valid] || [])} · rejected #{length(state[:rejected] || [])}" <>
      " · transformed #{length(state[:transformed] || [])}" <>
      " · loaded #{state[:loaded_count] || 0} to destination (#{state[:destination_checksum] || "dp-000000000"})"
  end

  @doc """
  Resolve a full pipeline projection from a (possibly partial) agent state.

  Steps that run out of order still have what they need: when an earlier step
  has not stored its result, it is derived from the collected `ingested`
  records. Returns a map with `valid`, `rejected`, `transformed`,
  `loaded_count`, and `destination_checksum` filled in.
  """
  @spec resolve(map()) :: map()
  def resolve(state) do
    ingested = state[:ingested] || []

    {valid, rejected} = resolve_valid_rejected(state, ingested)
    transformed = resolve_transformed(state, valid)
    {loaded_count, destination_checksum} = resolve_loaded(state, transformed)

    %{
      valid: valid,
      rejected: rejected,
      transformed: transformed,
      loaded_count: loaded_count,
      destination_checksum: destination_checksum
    }
  end

  # Use the stored validation result when it is present, or when nothing was
  # collected (so an unloaded batch keeps its empty result). Otherwise re-run
  # validation against the collected batch.
  defp resolve_valid_rejected(state, ingested) do
    stored_valid = state[:valid]
    stored_rejected = state[:rejected]

    if use_stored_validation?(stored_valid, stored_rejected, ingested) do
      {stored_valid, stored_rejected}
    else
      validate(ingested)
    end
  end

  defp use_stored_validation?(valid, rejected, ingested)
       when is_list(valid) and is_list(rejected) do
    valid != [] or ingested == []
  end

  defp use_stored_validation?(_valid, _rejected, _ingested), do: false

  # Use the stored transformed batch when it is present; otherwise derive it
  # from the valid records.
  defp resolve_transformed(state, valid) do
    case state[:transformed] do
      list when is_list(list) and list != [] -> list
      _ -> transform(valid)
    end
  end

  # Use the stored load result when a checksum is present; otherwise load the
  # transformed batch.
  defp resolve_loaded(state, transformed) do
    case state[:destination_checksum] do
      checksum when is_binary(checksum) and checksum != "" ->
        {state[:loaded_count] || 0, checksum}

      _ ->
        result = load(transformed)
        {result.loaded_count, result.destination_checksum}
    end
  end

  defp blank?(nil), do: true
  defp blank?(""), do: true
  defp blank?(s) when is_binary(s), do: String.trim(s) == ""
  defp blank?(_), do: false
end
