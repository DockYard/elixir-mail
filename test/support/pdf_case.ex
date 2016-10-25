defmodule Pdf.Case do
  use ExUnit.CaseTemplate

  using do
    quote do
      import Pdf.Case
    end
  end

  def fixture(path),
    do: __DIR__ |> Path.join("fixtures") |> Path.join(path)

  def output(path),
    do: __DIR__ |> Path.join("../output") |> Path.join(path)

  def assert_unchanged(file_path, func) do
    path = Path.expand(file_path)
    if File.exists?(path) do
      changed_path = build_changed_path(path)
      try do
        original = File.read!(path)
        func.()
        changed = File.read!(path)

        if original != changed do
          failure_message = "PDF output has changed"
          File.write!(path, original) # Re-save original file
          diff = System.find_executable("diff")
          if diff do
            File.write!(changed_path, changed) # Save copy of changes
            case System.cmd(diff, ["-au", path, changed_path]) do # Do diff on changes
              {diff_results, 1} ->
                assert false, failure_message <> "\nDiff:\n" <> diff_results
              _ ->
                assert false, failure_message
            end
          else
            assert false, failure_message
          end
        end
      after
        if File.exists?(changed_path), do: File.rm(changed_path) # Delete copy of changes
      end
    else
      func.()
    end
  end

  defp build_changed_path(path) do
    [basename, ext] =
      path
      |> Path.basename
      |> String.split(".")
    Path.expand(Path.join(path, "../#{basename}-changed.#{ext}"))
  end
end
