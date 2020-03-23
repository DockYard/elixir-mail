defmodule Pdf.Stream do
  defstruct compress: 6, size: 0, dictionary: %{}, content: []

  import Pdf.Size
  import Pdf.Utils
  alias Pdf.Dictionary

  @stream_start "\nstream\n"
  @stream_end "endstream"

  def new(opts \\ []), do: init(opts, %__MODULE__{})

  defp init([], stream), do: stream

  defp init([{:compress, true} | tail], stream),
    do: init(tail, %{stream | compress: 6})

  defp init([{:compress, compress} | tail], stream),
    do: init(tail, %{stream | compress: compress})

  defp init([{:dictionary, dictionary} | tail], stream),
    do: init(tail, %{stream | dictionary: dictionary})

  defp init([_ | tail], stream),
    do: init(tail, stream)

  def push(stream, {:command, _} = command) do
    size = size_of(command) + 1
    %{stream | size: stream.size + size, content: ["\n", command | stream.content]}
  end

  def push(stream, command), do: push(stream, c(command))

  def set(stream, content) when is_binary(content) do
    size = byte_size(content)
    %{stream | size: size, content: [content]}
  end

  def to_iolist(%{compress: false} = stream) do
    dictionary = Dictionary.new(Map.merge(stream.dictionary, %{"Length" => stream.size}))

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
      Dictionary.new(
        Map.merge(stream.dictionary, %{
          "Length" => byte_size(compressed),
          "Filter" => n("FlateDecode")
        })
      )

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
    compressed = :zlib.deflate(z, iodata, :finish)
    :zlib.deflateEnd(z)
    IO.iodata_to_binary(compressed)
  end

  defimpl Pdf.Export do
    def to_iolist(stream), do: Pdf.Stream.to_iolist(stream)
  end
end
