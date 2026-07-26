defmodule AgentJidoWeb.ContentAssistantSupportTest do
  use ExUnit.Case, async: true

  alias AgentJido.ContentAssistant.Response
  alias AgentJidoWeb.ContentAssistantSupport

  describe "llm_request_outcome/1" do
    test "categorizes provider setup problems distinctly (jido-e12-t24)" do
      # The acceptance condition: provider setup problems are categorized. Each
      # enhancement-block signal (no provider/key, quota exhausted, verification
      # gate) maps to its own reason — never collapsing into a generic "error".
      assert ContentAssistantSupport.llm_request_outcome(response(answer_mode: :deterministic, enhancement_blocked_reason: :llm_unconfigured)) == %{
               outcome: "failed",
               reason: "provider_unconfigured"
             }

      assert ContentAssistantSupport.llm_request_outcome(response(answer_mode: :deterministic, enhancement_blocked_reason: :budget)) == %{
               outcome: "failed",
               reason: "provider_quota"
             }

      assert ContentAssistantSupport.llm_request_outcome(response(answer_mode: :deterministic, enhancement_blocked_reason: :turnstile)) == %{
               outcome: "failed",
               reason: "verification_required"
             }
    end

    test "a setup block wins over a served fallback answer" do
      # A visitor may still be served a grounded deterministic answer while the
      # LLM request itself failed for a setup reason — that failure is what we
      # categorize, so it is not masked by the served answer.
      outcome =
        ContentAssistantSupport.llm_request_outcome(response(answer_mode: :deterministic_fallback, enhancement_blocked_reason: :llm_unconfigured))

      assert outcome == %{outcome: "failed", reason: "provider_unconfigured"}
    end

    test "categorizes non-setup outcomes" do
      assert ContentAssistantSupport.llm_request_outcome(response(answer_mode: :no_results)) ==
               %{outcome: "failed", reason: "no_results"}

      assert ContentAssistantSupport.llm_request_outcome(response(answer_mode: :error)) ==
               %{outcome: "failed", reason: "error"}

      assert ContentAssistantSupport.llm_request_outcome(response(answer_mode: :deterministic)) ==
               %{outcome: "succeeded", reason: "succeeded"}

      assert ContentAssistantSupport.llm_request_outcome(response(answer_mode: :llm)) ==
               %{outcome: "succeeded", reason: "succeeded"}
    end

    test "a missing response (task crash) categorizes as a failed error" do
      assert ContentAssistantSupport.llm_request_outcome(nil) ==
               %{outcome: "failed", reason: "error"}
    end

    test "exposes the full reason enum so the dashboard and tests agree" do
      assert "provider_unconfigured" in ContentAssistantSupport.llm_request_outcome_reasons()
      assert "provider_quota" in ContentAssistantSupport.llm_request_outcome_reasons()
      assert "verification_required" in ContentAssistantSupport.llm_request_outcome_reasons()
      assert "succeeded" in ContentAssistantSupport.llm_request_outcome_reasons()
    end
  end

  defp response(overrides) do
    %Response{
      query: "test query",
      answer_markdown: "answer",
      answer_html: "<p>answer</p>",
      answer_mode: :deterministic,
      citations: [],
      retrieval_status: :success,
      llm_attempted?: false,
      llm_enhanced?: false,
      enhancement_blocked_reason: nil,
      query_log_id: nil
    }
    |> struct(overrides)
  end
end
