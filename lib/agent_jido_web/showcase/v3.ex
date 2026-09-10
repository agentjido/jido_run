defmodule AgentJidoWeb.Showcase.V3 do
  @moduledoc """
  Static code samples for the unlisted Jido V3 showcase.

  The samples are display text. This application does not compile or run them.
  """

  @agent ~S"""
  defmodule MyApp.Counter do
    use Jido.Agent, name: "counter"

    agent do
      schema Zoi.object(%{
        count: Zoi.integer() |> Zoi.default(0)
      })
    end

    routes do
      signal_source "/counter"

      route "counter.increment" do
        action %{amount: amount}, context: context do
          {:ok, %{
            context.agent_state
            | count: context.agent_state.count + amount
          }}
        end

        defaults %{amount: 1}
        define :increment, args: [{:optional, :amount}]
      end
    end
  end
  """

  @flow ~S"""
  defmodule MyApp.PriceOrders do
    use Jido.Flow,
      name: "price_orders",
      schema: Zoi.object(%{orders: Zoi.array(Zoi.map())})

    flow do
      map "priced" do
        collection input(:orders)

        action order <- item() do
          total = order.quantity * order.unit_price
          {:ok, Map.put(order, :total, total)}
        end
      end

      reduce "summary" do
        collection result("priced")
        initial %{count: 0, revenue: 0}

        action [
          count <- accumulator(:count),
          revenue <- accumulator(:revenue),
          total <- item(:total)
        ] do
          {:ok, %{count: count + 1, revenue: revenue + total}}
        end
      end

      output %{
        orders: result("priced"),
        summary: result("summary")
      }
    end
  end

  {:ok, result} =
    Jido.Exec.run(MyApp.PriceOrders, input, %{},
      max_concurrency: 16
    )
  """

  @turn ~S"""
  {:ok, jido} = Jido.start()

  {:ok, server} =
    Jido.start_agent(MyApp.Counter,
      id: "counter-1"
    )

  {:ok, committed} = MyApp.Counter.increment(server, 2)

  committed.state.count
  #=> 2
  """

  @plugin ~S"""
  agent do
    schema Zoi.object(%{
      status: Zoi.string() |> Zoi.default("idle")
    })

    plugin MyApp.IdentityPlugin,
      config: [issuer: "my-app"]

    plugin MyApp.AuditPlugin
  end
  """

  @topology ~S"""
  defmodule MyApp.WorkerSwarm do
    use Jido.Topology, name: "worker_swarm"

    topology do
      agents do
        agent :coordinator, MyApp.Coordinator

        group :workers, MyApp.Worker do
          count 1_000
        end
      end

      resources do
        bus :work
      end

      relationships do
        owns :coordinator, :workers
      end

      connections do
        subscribe :workers,
          to: :work,
          path: "my_app.work.requested"
      end

      startup do
        concurrency 32
      end
    end
  end
  """

  @ai ~S"""
  defmodule MyApp.ResearchAgent do
    use Jido.AI.Agent, name: "research_agent"

    agent do
      ai :assistant do
        model(:capable)
        reasoning(:react)

        tools do
          action MyApp.Search
          action MyApp.Fetch
        end
      end
    end

    routes do
      route("research.ask", ai: :assistant)
    end
  end
  """

  @doc "Returns the static Elixir samples rendered by the V3 showcase."
  @spec snippets() :: %{
          agent: String.t(),
          ai: String.t(),
          flow: String.t(),
          plugin: String.t(),
          topology: String.t(),
          turn: String.t()
        }
  def snippets do
    %{
      agent: @agent,
      ai: @ai,
      flow: @flow,
      plugin: @plugin,
      topology: @topology,
      turn: @turn
    }
  end
end
