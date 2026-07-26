defmodule AgentJido.Demos.OpenTelemetryExport.Span do
  @moduledoc """
  An OpenTelemetry span exported by the `jido_otel` bridge (`jido-e08-t20`).

  Mirrors the fields an OTel collector receives for one span: a name (mapped
  from the Jido event prefix), a kind, the trace/span identity, a status, OTel
  attributes (mapped from Jido metadata), an optional duration, and an optional
  exception event.
  """

  defstruct [:name, :kind, :trace_id, :span_id, :parent_span_id, :status, :attributes, :duration_ns, :exception]

  @type kind :: :internal | :client
  @type status :: :unset | :ok | :error
  @type exception_event :: %{kind: atom(), message: String.t()}

  @type t :: %__MODULE__{
          name: String.t(),
          kind: kind(),
          trace_id: String.t(),
          span_id: String.t(),
          parent_span_id: String.t() | nil,
          status: status(),
          attributes: map(),
          duration_ns: non_neg_integer() | nil,
          exception: exception_event() | nil
        }

  @doc """
  Generates a fresh OpenTelemetry span id (8 bytes / 16 lowercase hex chars).
  """
  @spec new_id :: String.t()
  def new_id, do: Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)

  @doc """
  Generates a fresh OpenTelemetry trace id (16 bytes / 32 lowercase hex chars).
  """
  @spec new_trace_id :: String.t()
  def new_trace_id, do: Base.encode16(:crypto.strong_rand_bytes(16), case: :lower)
end
