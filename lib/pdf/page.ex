defmodule Pdf.Page do
  defstruct size: :a4, stream: nil, current_font: nil

  import Pdf.Utils
  alias Pdf.{Image, Stream}

  def new(opts \\ [size: :a4]), do: init(opts, %__MODULE__{stream: Stream.new()})

  defp init([], page), do: page
  defp init([{:size, size} | tail], page), do: init(tail, %{page | size: size})
  defp init([_ | tail], page), do: init(tail, page)

  def push(page, command), do: %{page | stream: Stream.push(page.stream, command)}

  def set_font(page, document, font_name, font_size) do
    font = document.fonts[font_name]
    page = %{page | current_font: font}
    push(page, [font.name, font_size, "Tf"])
  end

  def text_at(%{current_font: %{font: font}} = page, {x, y}, text, opts \\ []) do
    page
    |> push("BT")
    |> push([x, y, "Td"])
    |> push(kerned_text(font, text, Keyword.get(opts, :kerning, false)))
    |> push("ET")
  end

  def text_lines(page, {x, y}, lines, opts \\ []) do
    page
    |> push("BT")
    |> push([x, y, "Td"])
    |> push([14, "TL"])
    |> draw_lines(lines, opts)
    |> push("ET")
  end

  def add_image(page, {x, y}, %{name: image_name, image: %Image{width: width, height: height}}) do
    page
    |> push("q")
    |> push([width, 0, 0, height, x, y, "cm"])
    |> push([image_name, "Do"])
    |> push("Q")
  end

  defp kerned_text(_font, text, false) do
    [s(normalize_text(text)), "Tj"]
  end

  defp kerned_text(font, text, true) do
    text =
      text
      |> normalize_text()
      |> font.kern_text()
      |> Enum.map(fn
        str when is_binary(str) -> s(str)
        num -> num
      end)

    [Pdf.Array.new(text), "TJ"]
  end

  defp draw_lines(%{current_font: %{font: font}} = page, [line], opts) do
    push(page, kerned_text(font, line, Keyword.get(opts, :kerning, false)))
  end

  defp draw_lines(%{current_font: %{font: font}} = page, [line | tail], opts) do
    text = kerned_text(font, line, Keyword.get(opts, :kerning, false))
    draw_lines(push(page, text ++ ["T*"]), tail, opts)
  end

  defp normalize_text(text) when is_binary(text) do
    text
    |> normalize_unicode_characters()
    |> Pdf.Encoding.WinAnsi.encode()
    |> String.to_charlist()
  end

  # Only available from OTP 20.0
  if Kernel.function_exported?(:unicode, :characters_to_nfc_binary, 1) do
    defp normalize_unicode_characters(text) do
      :unicode.characters_to_nfc_binary(text)
    end
  else
    defp normalize_unicode_characters(text), do: text
  end

  defimpl Pdf.Size do
    def size_of(%Pdf.Page{} = page), do: Pdf.Size.size_of(page.stream)
  end

  defimpl Pdf.Export do
    def to_iolist(%Pdf.Page{} = page), do: Pdf.Export.to_iolist(page.stream)
  end
end
