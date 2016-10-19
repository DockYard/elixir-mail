defmodule Pdf.Page do
  defstruct stream: nil

  alias Pdf.Stream

  def new,
    do: %__MODULE__{stream: Stream.new}

  def push(page, command),
    do: %{page | stream: Stream.push(page.stream, command)}

  defimpl Pdf.Size do
    def size_of(%Pdf.Page{} = page),
      do: Pdf.Size.size_of(page.stream)
  end

  defimpl Pdf.Export do
    def to_iolist(%Pdf.Page{} = page),
      do: Pdf.Export.to_iolist(page.stream)
  end
end
