defmodule AgentJido.CorrelationVsPrincipalTest do
  @moduledoc """
  E06-T33: copy does not present Agent, Signal, user, or tenant IDs as
  authentication.

  The E06 backlog requires a page that distinguishes correlation IDs from
  authenticated principals (source: Jido Site Improvement Backlog 2026-07-23.md,
  row E06-T33). The acceptance condition is exact: *Copy does not present Agent,
  Signal, user, or tenant IDs as authentication.* Main targets: the Identity and
  Signals content.

  Per the E06 product decision not to restructure the documentation IA, the
  "page" is a dedicated `## Correlation IDs are not authentication` section on
  the authoritative identity-boundary page (Security and governance), reinforced
  on the Signals concept page — the same approach E06-T31 and E06-T32 took for
  "add a block" backlog rows (edit an existing page, do not add a route).

  This test asserts the dedicated section exists and carries the four claims the
  acceptance condition turns on, so the section cannot be removed or weakened
  without failing here:

    1. Jido's IDs (Agent, Signal, request/run/trace) are correlation metadata,
       not authenticated principals and never a credential.
    2. A user ID or tenant ID on a Signal is supplied/verified context, not
       proof the caller is that user or tenant.
    3. Verifying a principal is an application or platform boundary in front of
       Jido, not something Jido performs.
    4. The fail-closed `prepare_action/3` hook is the authorization point for
       missing principal/tenant context.

  The Signals page is checked too: it must state Jido does not authenticate
  carried metadata and must link the reader to the dedicated distinction, so a
  reader of the Signals guide cannot mistake an ID for authentication.
  """

  use ExUnit.Case, async: true

  # The two target pages, named in the backlog as "Identity and Signals guide".
  # Paths are relative to the repo root.
  @identity_page "priv/pages/docs/operations/security-and-governance.md"
  @signals_page "priv/pages/docs/concepts/signals.md"

  # A `## Correlation IDs are not authentication` section: the heading and its
  # body up to the next `##` heading (or end of document).
  @section_re ~r/^##[[:space:]]+Correlation IDs are not authentication\b.*?(?=^##[[:space:]]|\z)/ims

  # The claims the acceptance condition turns on, matched loosely so authors can
  # phrase the surrounding sentence naturally while the substance is enforced.
  @identity_claims [
    {"IDs are correlation, not authenticated principals", ~r/not authenticated principals/i},
    {"an ID is never a credential", ~r/\bcredential\b/i},
    {"Agent ID named as correlation", ~r/\bAgent ID\b/},
    {"Signal ID named as correlation", ~r/\bSignal ID\b/},
    {"user/tenant IDs are supplied context, not proof", ~r/not as proof the caller is that user or tenant/i},
    {"verifying a principal is an application or platform boundary in front of Jido", ~r/application or platform boundary in front of Jido/i},
    {"prepare_action/3 is the authorization hook", ~r{prepare_action/3}}
  ]

  describe "the identity page distinguishes correlation IDs from authenticated principals (jido-e06-t33)" do
    test "#{@identity_page} carries the dedicated section" do
      body = File.read!(repo_path(@identity_page))
      section = section(body)

      assert section != nil,
             "#{@identity_page} must include a `## Correlation IDs are not " <>
               "authentication` section"
    end

    for {label, re} <- @identity_claims do
      test "#{@identity_page} states: #{label}" do
        {label, re} = unquote(Macro.escape({label, re}))
        body = File.read!(repo_path(@identity_page))
        section = section(body)

        assert section != nil,
               "#{unquote(@identity_page)} must include a `## Correlation IDs " <>
                 "are not authentication` section before its claims can be checked"

        assert Regex.match?(re, section),
               "#{unquote(@identity_page)} Correlation IDs section must state #{label} " <>
                 "(matching #{inspect(re.source)})"
      end
    end
  end

  describe "the Signals page does not present IDs as authentication (jido-e06-t33)" do
    test "#{@signals_page} keeps IDs as correlation, not authenticated principals" do
      body = File.read!(repo_path(@signals_page))

      assert Regex.match?(~r/not authenticated principals/i, body),
             "#{@signals_page} must state that IDs are correlation, not " <>
               "authenticated principals"
    end

    test "#{@signals_page} does not present carried metadata as authentication" do
      body = File.read!(repo_path(@signals_page))

      # The extension note must state Jido carries metadata and does not
      # authenticate it, so a reader cannot infer that a user/tenant ID on a
      # Signal is a credential Jido issues or checks.
      assert Regex.match?(~r/does not authenticate/i, body),
             "#{@signals_page} must state Jido does not authenticate the " <>
               "metadata a Signal carries"

      assert Regex.match?(~r/correlation context, not as a credential/i, body),
             "#{@signals_page} must treat a user/tenant ID on a Signal as " <>
               "correlation context, not a credential"
    end

    test "#{@signals_page} links the reader to the dedicated distinction" do
      body = File.read!(repo_path(@signals_page))

      assert Regex.match?(~r{\(/docs/operations/security-and-governance\)}, body),
             "#{@signals_page} must link to Security and governance, where the " <>
               "correlation-vs-principal distinction is drawn in full"
    end
  end

  defp repo_path(relative) do
    Path.expand("../../" <> relative, __DIR__)
  end

  defp section(body) do
    case Regex.run(@section_re, body) do
      [section | _] -> section
      nil -> nil
    end
  end
end
