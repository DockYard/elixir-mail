defmodule Pdf.Stream do
  defstruct compress: false, size: 0, content: []

  import Pdf.Size
  import Pdf.Utils
  alias Pdf.Dictionary

  @stream_start "\nstream\n"
  @stream_end "endstream"

  def new(compress: level), do: %__MODULE__{compress: level}
  def new, do: %__MODULE__{}

  def push(stream, {:command, _} = command) do
    size = size_of(command) + 1
    %{stream | size: stream.size + size, content: ["\n", command | stream.content]}
  end

  def push(stream, command), do: push(stream, c(command))

  def to_iolist(%{compress: false} = stream) do
    dictionary = Dictionary.new(%{"Length" => stream.size})

    Pdf.Export.to_iolist([
      dictionary,
      @stream_start,
      Enum.reverse(stream.content),
      @stream_end
    ])
  end

  def to_iolist(%{compress: level} = stream) do
    compressed =
      stream.content
      |> Enum.reverse()
      |> Pdf.Export.to_iolist()
      # We would usually return a structure but now we need to export the structure so it can be compressed
      |> Pdf.Export.to_iolist()
      |> compress(level)

    dictionary =
      Dictionary.new(%{"Length" => byte_size(compressed), "Filter" => n("FlateDecode")})

    Pdf.Export.to_iolist([
      dictionary,
      @stream_start,
      compressed,
      @stream_end
    ])
  end

  defp compress(iodata, level) do
    z = :zlib.open()
    :zlib.deflateInit(z, level)
    [compressed] = :zlib.deflate(z, iodata, :finish)
    :zlib.deflateEnd(z)
    compressed
  end

  defimpl Pdf.Export do
    def to_iolist(stream), do: Pdf.Stream.to_iolist(stream)
  end
end
