defmodule AgentJido.ExamplesTaxonomyTest do
  use ExUnit.Case, async: true

  alias AgentJido.Examples.Taxonomy

  test "task labels cover the adoption-oriented jobs (E08-T01)" do
    tasks = Taxonomy.tasks()

    for label <- [
          :chat_and_support,
          :research,
          :coding,
          :browser_work,
          :data_and_documents,
          :scheduling,
          :persistence,
          :recovery,
          :coordination,
          :observability
        ] do
      assert label in tasks, "missing task label #{inspect(label)}"
    end
  end
end
