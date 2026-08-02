defmodule AgentJidoWeb.Layouts do
  use AgentJidoWeb, :html

  @home_critical_css_path Path.expand(
                            "../../../assets/css/home_critical.generated.css",
                            __DIR__
                          )
  @external_resource @home_critical_css_path
  @home_critical_css File.read!(@home_critical_css_path)

  embed_templates "layouts/*"

  @doc false
  @spec home_critical_css() :: String.t()
  def home_critical_css, do: @home_critical_css
end
