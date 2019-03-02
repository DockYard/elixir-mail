defmodule Mail.MIME do
  @doc """
  Returns the mimetype for a given file extension.

      Mail.Mimetype.type("md")
      "text/markdown"
  """
  def type(extension)

  for line <- File.stream!(Path.join([__DIR__, "mime.types"]), [], :line) do
    if String.starts_with?(line, ["#", "\n"]) do
      []
    else
      [type | exts] = line |> String.trim() |> String.split()

      Enum.each(exts, fn ext ->
        def type(unquote(ext)) do
          unquote(type)
        end
      end)
    end
  end

  def type(_ext), do: nil
end
