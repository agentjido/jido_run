---
name: demo-unit-converter
description: Converts temperature and distance inputs for the deterministic multi-skill orchestration demo.
license: Apache-2.0
allowed-tools: convert_temperature convert_distance
metadata:
  author: agent-jido-demo
  version: "1.0.0"
  jido_ai.tags: "demo conversion orchestration"
---

# Demo Unit Converter

Use this skill when the request is about temperature or distance conversions.

## Workflow

1. Identify the source and destination units.
2. Run the matching conversion helper.
3. Return the normalized result for any downstream specialist.

## Example Uses

- Convert 98.6 Fahrenheit to Celsius
- Convert 5 kilometers to miles
