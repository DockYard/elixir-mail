defmodule Pdf.Case do
  use ExUnit.CaseTemplate

  using do
    quote do
      import Pdf.Case
    end
  end

  def fixture(path), do: __DIR__ |> Path.join("fixtures") |> Path.join(path)

  def output(path), do: __DIR__ |> Path.join("../output") |> Path.join(path)

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
          # Re-save original file
          File.write!(path, original)
          diff = System.find_executable("diff")

          if diff do
            # Save copy of changes
            File.write!(changed_path, changed)
            # Do diff on changes
            case System.cmd(diff, ["-au", path, changed_path]) do
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
        # Delete copy of changes
        if File.exists?(changed_path), do: File.rm(changed_path)
      end
    else
      func.()
    end
  end

  defp build_changed_path(path) do
    [basename, ext] =
      path
      |> Path.basename()
      |> String.split(".")

    Path.expand(Path.join(path, "../#{basename}-changed.#{ext}"))
  end

  def export(%{stream: stream}) do
    (stream
     |> Pdf.Export.to_iolist()
     |> Pdf.Export.to_iolist()
     |> IO.chardata_to_string()
     |> String.split("\n")
     |> Enum.drop_while(&(&1 != "stream"))
     |> Enum.drop(1)
     |> Enum.take_while(&(&1 != "endstream"))
     |> Enum.join("\n")) <> "\n"
  end
end
