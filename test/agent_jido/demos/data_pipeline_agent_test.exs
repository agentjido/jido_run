defmodule AgentJido.Demos.DataPipelineAgentTest do
  use ExUnit.Case, async: true

  alias AgentJido.Demos.DataPipeline
  alias AgentJido.Demos.DataPipeline.Fixtures

  describe "DataPipeline.new/0" do
    test "starts with an empty batch and empty status, load, and report" do
      agent = DataPipeline.new()

      assert agent.state.sources_loaded == []
      assert agent.state.ingested == []
      assert agent.state.valid == []
      assert agent.state.rejected == []
      assert agent.state.transformed == []
      assert agent.state.loaded_count == 0
      assert agent.state.destination_checksum == ""
      assert agent.state.status == ""
      assert agent.state.report == ""
    end
  end

  describe "ingest/2" do
    test "collects one source's records and tags each with its source" do
      {agent, _} = DataPipeline.ingest(DataPipeline.new(), :orders)

      batch = Fixtures.fetch(:orders)

      assert agent.state.sources_loaded == ["orders"]
      assert length(agent.state.ingested) == length(batch.records)
      assert Enum.all?(agent.state.ingested, &(&1.source == "orders"))
      # A fresh collect clears the downstream output.
      assert agent.state.valid == []
      assert agent.state.transformed == []
      assert agent.state.report == ""
    end

    test "collects each source by name" do
      for which <- Fixtures.sources() do
        {agent, _} = DataPipeline.ingest(DataPipeline.new(), which)
        batch = Fixtures.fetch(which)

        assert agent.state.sources_loaded == [batch.source]
        assert length(agent.state.ingested) == length(batch.records)
      end
    end

    test "accumulates records across multiple sources without losing earlier ones" do
      {agent, _} =
        DataPipeline.new()
        |> DataPipeline.ingest(:orders)
        |> then(fn {a, _} -> DataPipeline.ingest(a, :users) end)

      assert agent.state.sources_loaded == ["orders", "users"]

      assert length(agent.state.ingested) ==
               length(Fixtures.fetch(:orders).records) + length(Fixtures.fetch(:users).records)
    end
  end

  describe "ingest_all/1" do
    test "collects every source in display order" do
      {agent, _} = DataPipeline.ingest_all(DataPipeline.new())

      assert agent.state.sources_loaded == Enum.map(Fixtures.sources(), &Fixtures.fetch(&1).source)

      total = Fixtures.sources() |> Enum.map(&(Fixtures.fetch(&1).records |> length())) |> Enum.sum()
      assert length(agent.state.ingested) == total
    end
  end

  describe "validate_records/1" do
    test "partitions the batch into valid and rejected by source schema" do
      {agent, _} =
        DataPipeline.new()
        |> DataPipeline.ingest_all()
        |> then(fn {a, _} -> DataPipeline.validate_records(a) end)

      # orders contributes two malformed records (empty customer and nil
      # amount); users and events each contribute one. The check is real.
      assert length(agent.state.rejected) == 4
      assert agent.state.status == "validated"
    end

    test "rejects the malformed order records for real reasons" do
      {agent, _} =
        DataPipeline.new()
        |> DataPipeline.ingest(:orders)
        |> then(fn {a, _} -> DataPipeline.validate_records(a) end)

      reasons = Enum.map(agent.state.rejected, & &1.reason) |> Enum.sort()

      assert "orders record missing amount_cents" in reasons
      assert "orders record missing customer" in reasons
      # The two valid orders survive.
      assert length(agent.state.valid) == 2
    end

    test "validates an empty (unloaded) batch as zero valid and zero rejected" do
      {agent, _} = DataPipeline.new() |> then(fn a -> DataPipeline.validate_records(a) end)

      assert agent.state.valid == []
      assert agent.state.rejected == []
    end
  end

  describe "transform_records/1" do
    test "normalizes the valid batch and derives canonical fields" do
      {agent, _} =
        DataPipeline.new()
        |> DataPipeline.ingest_all()
        |> then(fn {a, _} -> DataPipeline.validate_records(a) end)
        |> then(fn {a, _} -> DataPipeline.transform_records(a) end)

      orders = Enum.filter(agent.state.transformed, &(&1.source == "orders"))

      assert Enum.all?(orders, &(&1.currency == String.upcase(&1.currency)))
      assert Enum.all?(orders, &(is_float(&1.amount_usd) and &1.amount_usd == &1.amount_cents / 100))

      users = Enum.filter(agent.state.transformed, &(&1.source == "users"))
      assert Enum.all?(users, &(&1.email == String.downcase(&1.email)))
      assert Enum.all?(users, &(&1.country == String.upcase(&1.country)))

      events = Enum.filter(agent.state.transformed, &(&1.source == "events"))
      assert Enum.all?(events, &is_binary(&1.kind))
    end

    test "is self-sufficient: transforms with no prior validate step" do
      {agent, _} =
        DataPipeline.new()
        |> DataPipeline.ingest(:orders)
        |> then(fn {a, _} -> DataPipeline.transform_records(a) end)

      # Transform derives the valid set lazily, so the two valid orders still transform.
      assert length(agent.state.transformed) == 2
    end
  end

  describe "load_records/1" do
    test "writes the transformed batch and produces a stable checksum" do
      {agent_a, _} =
        DataPipeline.new()
        |> DataPipeline.ingest_all()
        |> then(fn {a, _} -> DataPipeline.transform_records(a) end)
        |> then(fn {a, _} -> DataPipeline.load_records(a) end)

      {agent_b, _} =
        DataPipeline.new()
        |> DataPipeline.ingest_all()
        |> then(fn {a, _} -> DataPipeline.transform_records(a) end)
        |> then(fn {a, _} -> DataPipeline.load_records(a) end)

      assert agent_a.state.status == "loaded"
      assert agent_a.state.loaded_count == length(agent_a.state.transformed)
      assert String.starts_with?(agent_a.state.destination_checksum, "dp-")
      # Two identical runs agree on the checksum.
      assert agent_a.state.destination_checksum == agent_b.state.destination_checksum
    end

    test "loads zero records for an empty batch with a stable empty checksum" do
      {agent, _} = DataPipeline.new() |> then(fn a -> DataPipeline.load_records(a) end)

      assert agent.state.loaded_count == 0
      assert String.starts_with?(agent.state.destination_checksum, "dp-")
    end
  end

  describe "summarize_run/1" do
    test "rolls the run up into one report and persists the resolved projection" do
      {agent, _} =
        DataPipeline.new()
        |> DataPipeline.ingest_all()
        |> then(fn {a, _} -> DataPipeline.summarize_run(a) end)

      assert agent.state.status == "summarized"
      assert agent.state.report =~ "pipeline complete"
      assert agent.state.report =~ "loaded"
      # Summarize resolved and persisted the full projection lazily.
      assert agent.state.loaded_count > 0
      assert String.starts_with?(agent.state.destination_checksum, "dp-")
    end

    test "is self-sufficient: summarizes with no prior validate, transform, or load step" do
      {agent, _} =
        DataPipeline.new()
        |> DataPipeline.ingest(:orders)
        |> then(fn {a, _} -> DataPipeline.summarize_run(a) end)

      # The two valid orders flow all the way through to a loaded count.
      assert agent.state.loaded_count == 2
      assert agent.state.report =~ "ingested 4"
      assert agent.state.report =~ "valid 2"
      assert agent.state.report =~ "rejected 2"
    end
  end

  describe "full collect -> validate -> transform -> load -> summarize workflow" do
    test "the five typed actions compose into a scheduled ETL pipeline" do
      {agent, _} =
        DataPipeline.new()
        |> DataPipeline.ingest_all()
        |> then(fn {a, _} -> DataPipeline.validate_records(a) end)
        |> then(fn {a, _} -> DataPipeline.transform_records(a) end)
        |> then(fn {a, _} -> DataPipeline.load_records(a) end)
        |> then(fn {a, _} -> DataPipeline.summarize_run(a) end)

      # 10 records collected (4 orders + 3 users + 3 events), 6 valid, 4 rejected.
      assert length(agent.state.ingested) == 10
      assert length(agent.state.valid) == 6
      assert length(agent.state.rejected) == 4
      assert length(agent.state.transformed) == 6
      assert agent.state.loaded_count == 6
      assert String.starts_with?(agent.state.destination_checksum, "dp-")
      assert agent.state.report =~ "loaded 6"
    end
  end
end
