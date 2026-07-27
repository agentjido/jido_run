%{
title: "Fix note: the first-LLM tutorial no longer fails on a provider mismatch",
author: "Mike Hostetler",
tags: ~w(jido elixir jido_ai req_llm livebook fix-note),
description: "A first-LLM Livebook example failed because the tutorial paired an OpenAI key with a model alias that resolved to another provider. The cause, the correction, and the regression test that holds it.",
post_type: :post,
audience: :general,
journey_stage: :activation,
content_intent: :reference,
capability_theme: :ai_intelligence,
evidence_surface: :runnable_example
}
---

This is a public fix note: a real problem an adopter hit, the cause, the
correction, and the regression test that keeps the behavior locked. It is the
first concrete example of the path the [community failure-story
request](/community#community-failure-stories) describes — a reproducible fault
turned into a public note and a test.

## What happened

An adopter following the [Your first LLM agent](/docs/getting-started/first-llm-agent)
guide in Livebook reported that the example failed on the first request. The
report and discussion are public on the
[Elixir Forum](https://forum.elixirforum.com/t/trying-first-llm-example-in-livebook-fails/76075).

## Cause

The notebook configured an OpenAI key:

```elixir
ReqLLM.put_key(:openai_api_key, openai_key)
```

…but selected the `:fast` model alias for the request. Each alias resolves to
exactly one fixed provider, and `:fast` resolves to an **Anthropic** model. The
configured key (OpenAI) and the selected model (Anthropic) were therefore on
different providers, so the request could not authenticate and failed before it
ever reached the model. This is the most common first-run failure: a
provider/model mismatch where the key and the model disagree.

## Correction

The guide now selects an explicit `openai:` model that matches the OpenAI key:

```elixir
model: "openai:gpt-4o-mini"
```

Naming a concrete provider and model removes the ambiguity the alias introduced.
The rule the guide now states plainly: **the configured key provider and the
selected model provider must match, and the model must be explicit on the first
request.** Model aliases are convenient and are introduced later, once an
explicit request has succeeded — and `llm_db` resolves each alias to a concrete
provider and model so the match is visible when aliases are adopted.

## Regression protection

A regression test holds the correction so the fault cannot silently return.
`test/agent_jido/first_llm_tutorial_consistency_test.exs` reads the guide's
source and asserts three things:

1. the guide configures an OpenAI key,
2. the guide selects an explicit `openai:` model that matches that key, and
3. the guide uses **no** model alias (`:fast`, `:capable`, `:reasoning`,
   `:thinking`, `:planning`, `:image`, `:embedding`), because each alias
   resolves to one fixed provider and can silently mismatch the key.

If the guide is ever edited back toward an alias, the test fails. The test is
the thing that survives — the note documents it.

## What this is, and is not

This note does not name the reporter and makes no claim beyond what the
reproduction and the test lock. It is the pattern we want every production
failure to follow: hand us a reproduction, get back a public note naming cause
and correction, and a regression test that holds the line. If Jido fails for
you in a real system, [tell us](https://github.com/agentjido/agentjido_xyz/issues)
— the next fix note can be yours.
