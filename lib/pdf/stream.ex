defmodule Pdf.Stream do
  defstruct size: 0, content: []

  import Pdf.Size
  alias Pdf.Dictionary

  @stream_start "\nstream\n"
  @stream_end "endstream"

  def new,
    do: %__MODULE__{}

  def push(stream, command) do
    size = size_of(command) + 1
    %{stream | size: stream.size + size, content: ["\n", command | stream.content]}
  end

  def size(stream) do
    dictionary = Dictionary.new |> Dictionary.put("Length", stream.size)
    Dictionary.size(dictionary) + stream.size
  end

  def to_iolist(stream) do
    dictionary = Dictionary.new(%{"Length" => stream.size})

    Pdf.Export.to_iolist([
      dictionary,
      @stream_start,
      Enum.reverse(stream.content),
      @stream_end
    ])
  end

  defimpl Pdf.Size do
    def size_of(%Pdf.Stream{} = stream),
      do: Pdf.Stream.size(stream)
  end

  defimpl Pdf.Export do
    def to_iolist(stream),
      do: Pdf.Stream.to_iolist(stream)
  end
end
