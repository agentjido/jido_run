defmodule AgentJido.ContentGen.Audit.SourceIndexTest do
  use ExUnit.Case, async: true

  alias AgentJido.ContentGen.Audit.SourceIndex

  test "indexes sibling package modules and exports" do
    root = tmp_dir!("content_gen_source_index")
    package_dir = Path.join([root, "jido", "lib", "jido"])
    :ok = File.mkdir_p(package_dir)

    source_file = Path.join(package_dir, "worker.ex")

    File.write!(
      source_file,
      """
      defmodule Jido.Worker do
        @callback cmd(term(), map(), keyword()) :: {:ok, term()}
        def run(input), do: {:ok, input}
        defmacro demo(value), do: value
      end
      """
    )

    index = SourceIndex.build(source_root: root, packages: ["jido"])

    assert index.scanned_files == 1
    assert SourceIndex.module_exists?(index, "Jido.Worker")
    assert SourceIndex.export_exists?(index, "Jido.Worker", "run", 1)
    assert SourceIndex.export_exists?(index, "Jido.Worker", "demo", 1)
    assert SourceIndex.export_exists?(index, "Jido.Worker", "cmd", 3)
    refute SourceIndex.export_exists?(index, "Jido.Worker", "missing", 0)
  end

  test "normalize restores MapSets from list-shaped Runic payloads" do
    index =
      SourceIndex.normalize(%{
        "modules" => ["Jido.Worker"],
        "exports" => [{"Jido.Worker", "run", 1}],
        "package_paths" => %{"jido" => "/tmp/jido"},
        "scanned_files" => 1
      })

    assert %MapSet{} = index.modules
    assert %MapSet{} = index.exports
    assert SourceIndex.module_exists?(index, "Jido.Worker")
    assert SourceIndex.export_exists?(index, "Jido.Worker", "run", 1)
  end

  defp tmp_dir!(prefix) do
    path = Path.join(System.tmp_dir!(), "#{prefix}_#{System.unique_integer([:positive])}")
    :ok = File.mkdir_p(path)
    on_exit(fn -> File.rm_rf(path) end)
    path
  end
end
