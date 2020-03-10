defmodule Pdf.Page do
  defstruct size: :a4, stream: nil

  import Pdf.Utils
  alias Pdf.{Image, Stream}

  def new(opts \\ [size: :a4]), do: init(opts, %__MODULE__{stream: Stream.new()})

  defp init([], page), do: page
  defp init([{:size, size} | tail], page), do: init(tail, %{page | size: size})
  defp init([_ | tail], page), do: init(tail, page)

  def push(page, command), do: %{page | stream: Stream.push(page.stream, command)}

  def set_font(page, document, font_name, font_size) do
    font = document.fonts[font_name]
    push(page, [font.name, font_size, "Tf"])
  end

  def text_at(page, {x, y}, text) do
    page
    |> push("BT")
    |> push([x, y, "Td"])
    |> push([s(normalize_text(text)), "Tj"])
    |> push("ET")
  end

  def text_lines(page, {x, y}, lines) do
    page
    |> push("BT")
    |> push([x, y, "Td"])
    |> push([14, "TL"])
    |> draw_lines(lines)
    |> push("ET")
  end

  def draw_lines(page, [line]) do
    push(page, [s(normalize_text(line)), "Tj"])
  end

  def draw_lines(page, [line | tail]) do
    draw_lines(push(page, [s(normalize_text(line)), "Tj", "T*"]), tail)
  end

  def add_image(page, {x, y}, %{name: image_name, image: %Image{width: width, height: height}}) do
    page
    |> push("q")
    |> push([width, 0, 0, height, x, y, "cm"])
    |> push([image_name, "Do"])
    |> push("Q")
  end

  defp normalize_text(text) when is_binary(text) do
    text
    |> :unicode.characters_to_nfc_binary()
    |> Pdf.Encoding.WinAnsi.encode()
    |> String.to_charlist()
  end

  defimpl Pdf.Size do
    def size_of(%Pdf.Page{} = page), do: Pdf.Size.size_of(page.stream)
  end

  defimpl Pdf.Export do
    def to_iolist(%Pdf.Page{} = page), do: Pdf.Export.to_iolist(page.stream)
  end
end
