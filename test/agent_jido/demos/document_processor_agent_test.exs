defmodule AgentJido.Demos.DocumentProcessorAgentTest do
  use ExUnit.Case, async: true

  alias AgentJido.Demos.DocumentProcessor
  alias AgentJido.Demos.DocumentProcessor.Fixtures

  describe "DocumentProcessor.new/0" do
    test "starts with empty document, classification, fields, and routing" do
      agent = DocumentProcessor.new()

      assert agent.state.incoming_document == ""
      assert agent.state.classification == ""
      assert agent.state.extracted_fields == ""
      assert agent.state.routing == ""
    end
  end

  describe "load_document/2" do
    test "loads the named fixture and resets the pipeline" do
      agent = DocumentProcessor.new()
      {agent, _} = DocumentProcessor.load_document(agent, :invoice)

      assert agent.state.incoming_document == Fixtures.fetch(:invoice)
      # A fresh load clears any prior pipeline output.
      assert agent.state.classification == ""
      assert agent.state.extracted_fields == ""
      assert agent.state.routing == ""
    end

    test "loads each fixture by name" do
      for which <- [:invoice, :contract, :ticket, :unknown] do
        {agent, _} = DocumentProcessor.load_document(DocumentProcessor.new(), which)
        assert agent.state.incoming_document == Fixtures.fetch(which)
      end
    end
  end

  describe "classify/1" do
    test "classifies the invoice, contract, and ticket fixtures for real" do
      for {which, expected} <- [invoice: "invoice", contract: "contract", ticket: "ticket"] do
        {agent, _} =
          DocumentProcessor.new()
          |> DocumentProcessor.load_document(which)
          |> then(fn {a, _} -> DocumentProcessor.classify(a) end)

        # The classification is a real keyword-scored match, not a canned label.
        assert agent.state.classification == expected
      end
    end

    test "classifies a document with none of the signals as unknown" do
      {agent, _} =
        DocumentProcessor.new()
        |> DocumentProcessor.load_document(:unknown)
        |> then(fn {a, _} -> DocumentProcessor.classify(a) end)

      assert agent.state.classification == "unknown"
    end

    test "classifies an empty document as unknown" do
      {agent, _} = DocumentProcessor.new() |> then(fn a -> DocumentProcessor.classify(a) end)

      assert agent.state.classification == "unknown"
    end
  end

  describe "extract/1" do
    test "extracts the invoice number, total, and due date" do
      {agent, _} =
        DocumentProcessor.new()
        |> DocumentProcessor.load_document(:invoice)
        |> then(fn {a, _} -> DocumentProcessor.extract(a) end)

      assert agent.state.extracted_fields =~ "Invoice number: INV-20431"
      assert agent.state.extracted_fields =~ "Total due: 1,302.00"
      assert agent.state.extracted_fields =~ "Due date: 2026-08-15"
    end

    test "extracts the contract parties and effective date" do
      {agent, _} =
        DocumentProcessor.new()
        |> DocumentProcessor.load_document(:contract)
        |> then(fn {a, _} -> DocumentProcessor.extract(a) end)

      assert agent.state.extracted_fields =~ "Effective date: 2026-07-01"
      # The two named parties are pulled out, decoration stripped.
      assert agent.state.extracted_fields =~ "Acme LLC / Initech"
    end

    test "extracts the ticket subject and priority" do
      {agent, _} =
        DocumentProcessor.new()
        |> DocumentProcessor.load_document(:ticket)
        |> then(fn {a, _} -> DocumentProcessor.extract(a) end)

      assert agent.state.extracted_fields =~ "Ticket number: TKT-9087"
      assert agent.state.extracted_fields =~ "Priority: high"
    end

    test "reports no fields for an unrecognized document" do
      {agent, _} =
        DocumentProcessor.new()
        |> DocumentProcessor.load_document(:unknown)
        |> then(fn {a, _} -> DocumentProcessor.classify(a) end)
        |> then(fn {a, _} -> DocumentProcessor.extract(a) end)

      assert agent.state.extracted_fields =~ "No extractable fields"
    end
  end

  describe "route/1" do
    test "escalates a high-value invoice" do
      {agent, _} =
        DocumentProcessor.new()
        |> DocumentProcessor.load_document(:invoice)
        |> then(fn {a, _} -> DocumentProcessor.route(a) end)

      # The fixture invoice total ($1,302) is at or above the escalation threshold.
      assert agent.state.routing =~ "accounts-payable-escalation"
    end

    test "routes a contract to legal review" do
      {agent, _} =
        DocumentProcessor.new()
        |> DocumentProcessor.load_document(:contract)
        |> then(fn {a, _} -> DocumentProcessor.route(a) end)

      assert agent.state.routing == "legal-review"
    end

    test "routes a high-priority ticket to the higher support tier" do
      {agent, _} =
        DocumentProcessor.new()
        |> DocumentProcessor.load_document(:ticket)
        |> then(fn {a, _} -> DocumentProcessor.route(a) end)

      assert agent.state.routing =~ "support-tier-2"
    end

    test "routes an unrecognized document to manual triage" do
      {agent, _} =
        DocumentProcessor.new()
        |> DocumentProcessor.load_document(:unknown)
        |> then(fn {a, _} -> DocumentProcessor.route(a) end)

      assert agent.state.routing == "manual-triage"
    end
  end

  describe "full load -> classify -> extract -> route workflow" do
    test "the four typed actions compose into a document-processing pipeline" do
      {agent, _} =
        DocumentProcessor.new()
        |> DocumentProcessor.load_document(:invoice)
        |> then(fn {a, _} -> DocumentProcessor.classify(a) end)
        |> then(fn {a, _} -> DocumentProcessor.extract(a) end)
        |> then(fn {a, _} -> DocumentProcessor.route(a) end)

      assert agent.state.classification == "invoice"
      assert agent.state.extracted_fields =~ "Invoice number: INV-20431"
      assert agent.state.routing =~ "accounts-payable-escalation"
    end
  end
end
