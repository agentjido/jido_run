defmodule AgentJido.Ecosystem.ControlMatrix do
  @moduledoc """
  The operational-control capability matrix (`jido-e09-t49`).

  A consolidated view that lets a reader compare the nine operational-control
  dimensions a production agent touches — context, authorization hooks, policy,
  quotas, history, observation, export, approval, and integration duties —
  across the packages that participate in the controlled-Agent stack and the
  host application that owns the rest.

  Each cell states what its column supplies for that dimension and is tagged
  with a role so the view can show which control comes from core Jido, an
  optional Jido package, or the host application — the boundary the E09 epic
  exit criteria require.

  Acceptance condition (E09-T49): *a reader can compare context, authorization
  hooks, policy, quotas, history, observation, export, approval, and
  integration duties.* The matrix exposes exactly those nine dimensions as rows,
  with one column per control package plus a host-application column, so the
  comparison the backlog names is visible in one place.

  The cell text is grounded in each package's documented control surface
  (`control_capabilities` / `control_limitations`, jido-e09-t41) and the
  Security and governance claim boundaries; no cell asserts a control the
  released and tested behavior does not support. Experimental or unreleased
  packages (`jido_otel`, `ash_jido`) describe their documented boundary only —
  the release basis and proof for every claim live on each package page
  (jido-e09-t47).
  """

  alias AgentJido.Ecosystem

  @type role :: :supplies | :preserves | :app

  @type column :: %{
          key: String.t(),
          label: String.t(),
          kind: :package | :host,
          path: String.t() | nil
        }

  @type capability :: %{
          key: atom(),
          label: String.t(),
          description: String.t()
        }

  @type cell :: %{role: role(), text: String.t()}

  @type row :: %{
          key: atom(),
          label: String.t(),
          description: String.t(),
          cells: %{String.t() => cell()}
        }

  # The control packages that participate in the controlled-Agent stack, in
  # display order, followed by the synthetic host-application column that owns
  # everything the packages leave to the application or platform. Package
  # columns link to their ecosystem page; the host column does not.
  @columns [
    %{key: "jido", label: "jido", kind: :package, path: "/ecosystem/jido"},
    %{key: "jido_action", label: "jido_action", kind: :package, path: "/ecosystem/jido_action"},
    %{key: "jido_signal", label: "jido_signal", kind: :package, path: "/ecosystem/jido_signal"},
    %{key: "jido_ai", label: "jido_ai", kind: :package, path: "/ecosystem/jido_ai"},
    %{key: "ash_jido", label: "ash_jido", kind: :package, path: "/ecosystem/ash_jido"},
    %{key: "jido_otel", label: "jido_otel", kind: :package, path: "/ecosystem/jido_otel"},
    %{key: "host", label: "Host application", kind: :host, path: nil}
  ]

  # The nine dimensions the backlog names, in comparison order. Each carries a
  # one-line description so a reader can compare like-for-like across columns.
  @capabilities [
    %{
      key: :context,
      label: "Context",
      description: "Principal, tenant, and trace context carried with a unit of work."
    },
    %{
      key: :authorization_hooks,
      label: "Authorization hooks",
      description: "Where a protected action can be permitted or denied before it runs."
    },
    %{
      key: :policy,
      label: "Policy",
      description: "Rules that shape what an action or tool is allowed to do."
    },
    %{
      key: :quotas,
      label: "Quotas",
      description: "Bounds on requests or tokens for AI work."
    },
    %{
      key: :history,
      label: "History",
      description: "A durable, replayable record of what happened."
    },
    %{
      key: :observation,
      label: "Observation",
      description: "The in-process events and spans that describe a running system."
    },
    %{
      key: :export,
      label: "Export",
      description: "Shipping observation to an external collector or backend."
    },
    %{
      key: :approval,
      label: "Approval",
      description: "A human or service sign-off before work proceeds."
    },
    %{
      key: :integration_duties,
      label: "Integration duties",
      description: "What each column leaves for the application or platform to own."
    }
  ]

  # The cell grid, keyed by capability then column. Roles:
  #   :supplies  — the column provides this control
  #   :preserves — the column carries or preserves context but the host decides
  #   :app       — the application or platform owns this; the column does not
  #                supply it (the honest boundary)
  #
  # Cell text is a clause, grounded in each package's documented control surface
  # and the Security and governance claim boundaries. Two dimensions — approval
  # and integration duties — are application-owned by design: no package ships an
  # approval workflow or takes over integration, and the matrix says so rather
  # than implying one exists.
  @rows %{
    context: %{
      "jido" =>
        {:preserves, "Carries principal, tenant, and trace context on Signals; the IDs are correlation metadata, not authenticated principals."},
      "jido_action" => {:app, "Caller identity and tenant are supplied by the host and carried on the Signal."},
      "jido_signal" => {:preserves, "Causation and correlation IDs link each record to its trace; correlation metadata."},
      "jido_ai" => {:app, "Principal and tenant are supplied by the host on the incoming Signal."},
      "ash_jido" => {:preserves, "Preserves the Ash actor, tenant, and authorization context."},
      "jido_otel" => {:preserves, "Propagates trace context as OpenTelemetry spans."},
      "host" => {:app, "Verifies and supplies the authenticated principal and tenant at the boundary."}
    },
    authorization_hooks: %{
      "jido" => {:supplies, "prepare_signal/2 and the fail-closed prepare_action/3 plugin hooks — integration points, not decisions."},
      "jido_action" => {:app, "Validates the contract, not who may call it; use prepare_action/3."},
      "jido_signal" => {:app, "Not supplied."},
      "jido_ai" => {:app, "Tool and effect policy rejects before run; not identity authorization."},
      "ash_jido" => {:preserves, "Preserves Ash authorization context; the host Ash app enforces."},
      "jido_otel" => {:app, "Not supplied."},
      "host" => {:app, "Owns the authorization decision and the RBAC/ABAC enforcement."}
    },
    policy: %{
      "jido" => {:app, "Not supplied."},
      "jido_action" => {:supplies, "Schema-validates action params before an action runs."},
      "jido_signal" => {:app, "Not supplied."},
      "jido_ai" => {:supplies, "Tool allowlists, effect policies, and prompt policies."},
      "ash_jido" => {:preserves, "Ash policies and validations run unchanged."},
      "jido_otel" => {:app, "Not supplied."},
      "host" => {:app, "Owns the policy source the plugins and Ash consult."}
    },
    quotas: %{
      "jido" => {:app, "Not supplied."},
      "jido_action" => {:app, "Not supplied."},
      "jido_signal" => {:app, "Not supplied."},
      "jido_ai" => {:supplies, "Request and token quotas; overall spend stays platform-owned."},
      "ash_jido" => {:app, "Not supplied."},
      "jido_otel" => {:app, "Not supplied."},
      "host" => {:app, "Owns overall spend limits and billing enforcement."}
    },
    history: %{
      "jido" => {:app, "Core observation is an ephemeral event stream, not an audit log."},
      "jido_action" => {:app, "Not supplied."},
      "jido_signal" => {:supplies, "Optional durable Signal Journal; default not durable; replayable, not tamper-evident."},
      "jido_ai" => {:app, "Not supplied."},
      "ash_jido" => {:app, "Not supplied."},
      "jido_otel" => {:app, "Not supplied."},
      "host" => {:app, "Owns retention, access control, tamper evidence, and deletion."}
    },
    observation: %{
      "jido" => {:supplies, "Jido.Observe and Jido.Telemetry emit in-process lifecycle, action, and span events."},
      "jido_action" => {:app, "Not supplied."},
      "jido_signal" => {:app, "Not supplied."},
      "jido_ai" => {:app, "Not supplied."},
      "ash_jido" => {:app, "Not supplied."},
      "jido_otel" => {:app, "Does not generate telemetry; consumes it for export."},
      "host" => {:app, "Owns durable audit evidence and incident response."}
    },
    export: %{
      "jido" => {:supplies, "Emits telemetry events any reporter can consume."},
      "jido_action" => {:app, "Not supplied."},
      "jido_signal" => {:app, "Not supplied."},
      "jido_ai" => {:app, "Not supplied."},
      "ash_jido" => {:app, "Not supplied."},
      "jido_otel" => {:supplies, "Exports Jido telemetry as OpenTelemetry spans to a collector."},
      "host" => {:app, "Owns the SIEM or telemetry backend."}
    },
    approval: %{
      "jido" => {:app, "Not supplied; wire an approval gate through prepare_action/3."},
      "jido_action" => {:app, "Not supplied."},
      "jido_signal" => {:app, "Not supplied."},
      "jido_ai" => {:app, "Not supplied."},
      "ash_jido" => {:app, "Not supplied."},
      "jido_otel" => {:app, "Not supplied."},
      "host" => {:app, "Owns the approval workflow; Jido supplies the hook to enforce it."}
    },
    integration_duties: %{
      "jido" => {:app, "Authentication, the authorization decision, and durable audit evidence."},
      "jido_action" => {:app, "Caller identity and tenant."},
      "jido_signal" => {:app, "Retention, access control, tamper evidence, and audit identity."},
      "jido_ai" => {:app, "Overall spend limits and billing."},
      "ash_jido" => {:app, "The Ash policies, actor, and authorization decisions."},
      "jido_otel" => {:app, "The collector and SIEM backend."},
      "host" => {:app, "Authentication/IAM, authorization policy, storage, and SIEM integration."}
    }
  }

  @doc "The nine operational-control dimensions, in comparison order."
  @spec capabilities() :: [capability()]
  def capabilities, do: @capabilities

  @doc "The control package columns plus the host-application column, in display order."
  @spec columns() :: [column()]
  def columns, do: @columns

  @doc "The column keys a reader compares across, in display order."
  @spec column_keys() :: [String.t()]
  def column_keys, do: Enum.map(@columns, & &1.key)

  @doc "The capability keys the backlog names, in comparison order."
  @spec capability_keys() :: [atom()]
  def capability_keys, do: Enum.map(@capabilities, & &1.key)

  @doc "Human-readable label for a cell role, used by the view legend."
  @spec role_label(role()) :: String.t()
  def role_label(:supplies), do: "Supplies"
  def role_label(:preserves), do: "Carries / preserves"
  def role_label(:app), do: "Application-owned"

  @doc """
  Enriched rows for the operational-control matrix view.

  Returns the nine capability rows in order, each carrying its label,
  description, and a cell per column. Every cell has a grounded role and a
  non-empty clause, and the grid is complete — one cell per (capability,
  column) — so the view never renders a gap.
  """
  @spec matrix() :: [row()]
  def matrix do
    column_keys = column_keys()

    Enum.map(@capabilities, fn capability ->
      cells = Map.fetch!(@rows, capability.key)

      %{
        key: capability.key,
        label: capability.label,
        description: capability.description,
        cells:
          Map.new(column_keys, fn col_key ->
            {role, text} = Map.fetch!(cells, col_key)
            {col_key, %{role: role, text: text}}
          end)
      }
    end)
  end

  @doc """
  The control package columns that resolve to a real public package.

  Used to assert the matrix never names a package the registry does not carry.
  """
  @spec package_columns() :: [column()]
  def package_columns do
    @columns
    |> Enum.filter(&(&1.kind == :package))
    |> Enum.filter(fn column -> Ecosystem.get_public_package(column.key) != nil end)
  end
end
