%{
  title: "Document Processor",
  description: "A real Jido agent that classifies an inbound document, extracts its fields, and routes it to a queue -- no LLM required.",
  tags: ["primary", "showcase", "core", "l1", "documents", "document"],
  category: :core,
  emoji: "📄",
  related_resources: [
    %{
      path: "/docs/getting-started/first-agent",
      kind: "Guide",
      description: "Define typed state and run your first command.",
      include_livebook: true
    },
    %{
      path: "/docs/concepts/actions",
      kind: "Concept",
      description: "Understand the action contracts this agent runs."
    },
    %{
      path: "/docs/concepts/signals",
      kind: "Concept",
      description: "See how typed Signals route each step of the pipeline."
    }
  ],
  source_files: [
    "lib/agent_jido/demos/document_processor/document_processor_agent.ex",
    "lib/agent_jido/demos/document_processor/classifier.ex",
    "lib/agent_jido/demos/document_processor/fixtures.ex",
    "lib/agent_jido/demos/document_processor/actions/load_document_action.ex",
    "lib/agent_jido/demos/document_processor/actions/classify_document_action.ex",
    "lib/agent_jido/demos/document_processor/actions/extract_fields_action.ex",
    "lib/agent_jido/demos/document_processor/actions/route_document_action.ex",
    "lib/agent_jido_web/examples/document_processor_live.ex"
  ],
  live_view_module: "AgentJidoWeb.Examples.DocumentProcessorLive",
  difficulty: :beginner,
  status: :live,
  scenario_cluster: :core_mechanics,
  wave: :l1,
  journey_stage: :evaluation,
  content_intent: :tutorial,
  capability_theme: :runtime_foundations,
  evidence_surface: :runnable_example,
  demo_mode: :real,
  sort_order: 4,
  outcome: "A real Jido agent that classifies an inbound document, extracts its fields, and routes it to a queue -- no LLM required.",
  packages: ["jido"],
  package_maturity: "Beta",
  prerequisites: ["Elixir 1.18+", "OTP 27+", "Jido installed"],
  expected_result: "Classify detects invoice, contract, or ticket; Extract pulls the invoice number and total, the contract parties, or the ticket priority; Route picks accounts-payable, legal-review, or a support tier.",
  run_command: "Run the interactive demo on /examples/document-processor."
}
---

## What you'll learn

- How to shape a document-processing workflow on the Jido runtime: load, classify, extract fields, route.
- How to encode each step as a typed, validated Action an agent runs through `cmd/2`.
- How to keep a document demo fully deterministic -- real keyword and pattern matching, no LLM, no API key.

## How it runs

This example runs a real `AgentJido.Demos.DocumentProcessor` agent. Load one of
the fixture documents (an invoice, a contract, or a support ticket), then run the
three typed actions in turn:

- `ClassifyDocument` scores the document text against real invoice, contract,
  and ticket signal phrases and picks the best match -- a document with none of
  the signals classifies as `unknown` instead of guessing.
- `ExtractFields` pulls structured fields from the text by type: an invoice
  yields its number, total, and due date; a contract its parties and effective
  date; a ticket its subject and priority.
- `RouteDocument` chooses a destination queue from the prior steps -- a
  high-value invoice escalates, a high-priority ticket goes to a higher support
  tier, and an unrecognized document lands in manual triage.

No LLM provider is called. The classification, extraction, and routing are
deterministic pattern matching on the document text, so you can run it without
an API key -- and swap a real reasoning strategy in later using the same agent
shape.
