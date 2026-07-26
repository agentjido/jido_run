defmodule AgentJido.ContentAssistant.Result do
  @moduledoc """
  Normalized citation result used by the content assistant.
  """

  @enforce_keys [:title, :snippet, :url, :source_type]
  defstruct [
    :title,
    :snippet,
    :url,
    :source_type,
    :score,
    :external?,
    :provider,
    :package_id,
    :package_name,
    :package_title,
    :package_version,
    :page_kind,
    :secondary_url
  ]

  @type source_type :: :docs | :blog | :ecosystem | :ecosystem_docs | :examples

  @type t :: %__MODULE__{
          title: String.t(),
          snippet: String.t(),
          url: String.t(),
          source_type: source_type(),
          score: number() | nil,
          external?: boolean() | nil,
          provider: atom() | String.t() | nil,
          package_id: String.t() | nil,
          package_name: String.t() | nil,
          package_title: String.t() | nil,
          package_version: String.t() | nil,
          page_kind: atom() | String.t() | nil,
          secondary_url: String.t() | nil
        }
end
