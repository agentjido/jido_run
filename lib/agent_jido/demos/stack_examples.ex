defmodule AgentJido.Demos.StackExamples do
  @moduledoc """
  One tested minimal example per recommended starting stack (`jido-e09-t09`).

  The home page names three recommended starting stacks — Core, AI, and
  Operate — and each ships a copyable mix.exs dependency block derived from the
  authoritative ecosystem registry (`jido-e09-t08`). This module gives each
  stack the matching minimal example that block promises: a small,
  self-contained program that runs against the stack's stated packages.

  Acceptance condition (E09-T09): *the example runs with the stated package
  versions.* Each example is real, compiled code — not a doc snippet — so the
  test suite executes `run/0` for every stack and proves the packages compose
  at the versions the home page states. The Core and AI examples run against
  every stated package, all of which are released to Hex and loaded in this
  project. The Operate example runs against `jido_messaging`, the stack's one
  loaded package; `ash_jido` and `jido_otel` are unreleased (their registry
  `hex_status` is `"unreleased"`), so the home dependency block pins their
  public GitHub repos — the same status the test asserts.

  Each nested stack module exposes:

    * `packages/0` — the stack's stated packages, matching the home page card
      and its dependency block (parity is asserted in the home live test).
    * `run/0` — executes the minimal example and returns a result map.

  `stacks/0` lists the three stack modules in home-page order so a test can
  drive them uniformly.
  """

  @doc """
  The three stack modules in home-page order.

  Each entry pairs the home page `data-stack` key with the example module, so a
  test can assert the example's stated packages match the stack a visitor sees.
  """
  @spec stacks :: [%{key: String.t(), name: String.t(), module: module()}]
  def stacks do
    [
      %{key: "core", name: "Core", module: __MODULE__.Core},
      %{key: "ai", name: "AI", module: __MODULE__.AI},
      %{key: "operate", name: "Operate", module: __MODULE__.Operate}
    ]
  end

  # ---------------------------------------------------------------- Core ----

  defmodule Core do
    @moduledoc """
    Minimal Core-stack example: a supervised agent, a typed Action, and the
    CloudEvents Signal the stack routes. Deterministic — no LLM, no network.

    Stated packages: `jido`, `jido_action`, `jido_signal`.
    """

    alias Jido.Signal

    defmodule IncrementAction do
      @moduledoc false
      use Jido.Action,
        name: "stack_core_increment",
        description: "Increments the Core-stack example counter.",
        schema: [by: [type: :integer, default: 1, doc: "Amount to increment by"]]

      @impl true
      def run(%{by: amount}, %{state: state}) do
        {:ok, %{count: Map.get(state, :count, 0) + amount}}
      end
    end

    defmodule Counter do
      @moduledoc false
      use Jido.Agent,
        name: "stack_core_counter",
        description: "Core-stack minimal example agent.",
        schema: [count: [type: :integer, default: 0]]
    end

    @doc "The stack's stated packages, matching the home dependency block."
    @spec packages :: [String.t()]
    def packages, do: ["jido", "jido_action", "jido_signal"]

    @doc """
    Run the minimal Core example.

    Builds the counter agent (`jido`), runs a validated Action that transitions
    its state (`jido_action`), and emits the CloudEvents Signal the Core stack
    routes between agents (`jido_signal`) — exercising every stated package.
    """
    @spec run :: map()
    def run do
      agent = Counter.new()
      {agent, _directives} = Counter.cmd(agent, {IncrementAction, %{by: 3}})

      signal = Signal.new!("stack_core.ping", %{count: agent.state.count}, source: "stack/core")

      %{count: agent.state.count, signal_type: signal.type, signal_data: signal.data}
    end
  end

  # ------------------------------------------------------------------ AI ----

  defmodule AI do
    @moduledoc """
    Minimal AI-stack example: an LLM-backed agent and its tool, the provider
    model the agent calls, and the metadata catalog that resolves it.

    The example composes the stack without making a network call — it resolves
    the model and constructs the agent — so it runs without a provider key,
    which is the bar a *minimal* example must clear. A builder adds the actual
    `ask` call on top.

    Stated packages: `jido_ai`, `req_llm`, `llm_db` (on top of the Core base).
    """

    defmodule LookupTool do
      @moduledoc false
      use Jido.Action,
        name: "stack_ai_lookup",
        description: "Returns a fixed answer for the AI-stack example.",
        schema: [query: [type: :string, required: true, doc: "The question to answer."]]

      @impl true
      def run(_params, _context) do
        {:ok, %{answer: "42"}}
      end
    end

    defmodule Agent do
      @moduledoc false
      use Jido.AI.Agent,
        name: "stack_ai_agent",
        description: "AI-stack minimal example agent.",
        tools: [LookupTool],
        model: :fast,
        streaming: false,
        system_prompt: "You answer the user's question concisely."
    end

    @doc "The stack's stated packages, matching the home dependency block."
    @spec packages :: [String.t()]
    def packages, do: ["jido_ai", "req_llm", "llm_db"]

    @doc """
    Run the minimal AI example.

    Resolves a provider model through `req_llm` (which consults the `llm_db`
    catalog), builds an enriched prompt through `jido_ai`, and constructs the
    AI agent wired with its tool (`jido_ai`). No provider request is made, so
    the example runs without an API key.
    """
    @spec run :: map()
    def run do
      alias Jido.AI.PromptBuilder

      # req_llm resolves the model id through the llm_db metadata catalog.
      {:ok, model} = ReqLLM.model("openai:gpt-4.1-mini")

      # jido_ai enriches the user prompt with retrieved context sections.
      prompt =
        PromptBuilder.build(
          "What is the answer to the ultimate question?",
          [{:known_facts, "The answer is 42."}]
        )

      # jido_ai constructs the agent, wiring the tool (a Core-stack Action).
      _agent = Agent.new()

      %{
        model_provider: model.provider,
        model_id: model.id,
        prompt: prompt,
        agent_constructed: true
      }
    end
  end

  # ------------------------------------------------------------ Operate ----

  defmodule Operate do
    @moduledoc """
    Minimal Operate-stack example: ship-to-production messaging integration.

    The stack's loaded package is `jido_messaging`, which this example runs end
    to end — create a room, save a message, read it back — over the in-memory
    ETS persistence adapter, exactly as a builder wires it into their app.

    The stack's other two packages are unreleased. `ash_jido` turns Ash
    resources into Jido Actions while preserving Ash authorization; `jido_otel`
    exports Jido telemetry as OpenTelemetry spans through the
    `Jido.Observe.Tracer` contract that the OpenTelemetry export demo
    (`AgentJido.Demos.OpenTelemetryExport`) exercises through its tracer bridge.
    Both have registry `hex_status` of `"unreleased"`, so the home dependency
    block pins their public GitHub repos — the status the test asserts.

    Stated packages: `ash_jido`, `jido_messaging`, `jido_otel`.
    """

    # The minimal wiring a builder pastes into their supervision tree:
    # `use Jido.Messaging` over the in-memory ETS persistence adapter, with the
    # app's PubSub supplied so messages can fan out to realtime consumers. The
    # PubSub name is an arbitrary, unique atom (not a module) so the example is
    # self-contained and never collides with the application's own PubSub; the
    # same atom is started in `run/0`.
    defmodule Bus do
      @moduledoc false
      use Jido.Messaging,
        persistence: Jido.Messaging.Persistence.ETS,
        pubsub: :stack_examples_operate_pubsub
    end

    @doc "The stack's stated packages, matching the home dependency block."
    @spec packages :: [String.t()]
    def packages, do: ["ash_jido", "jido_messaging", "jido_otel"]

    @doc """
    Run the minimal Operate example.

    Starts an ephemeral supervision tree (PubSub + the messaging instance), as
    a builder would in their app, then runs the messaging round-trip the
    `jido_messaging` package provides: create a room, save a message, read it
    back. The tree is torn down before returning so the example is
    self-contained.
    """
    @spec run :: map()
    def run do
      {:ok, sup} =
        Supervisor.start_link(
          [
            {Phoenix.PubSub, name: :stack_examples_operate_pubsub},
            Bus
          ],
          strategy: :one_for_one
        )

      try do
        {:ok, room} = Bus.create_room(%{type: :direct, name: "stack/operate"})

        {:ok, _saved} =
          Bus.save_message(%{
            room_id: room.id,
            sender_id: "stack",
            role: :user,
            content: [%{type: :text, text: "Hello, operate."}]
          })

        {:ok, messages} = Bus.list_messages(room.id)

        %{room_id: room.id, message_count: length(messages)}
      after
        Supervisor.stop(sup)
      end
    end
  end
end
