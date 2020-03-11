defmodule Pdf.Page do
  defstruct size: :a4, stream: nil, current_font: nil

  import Pdf.Utils
  alias Pdf.{Image, Stream}

  def new(opts \\ [size: :a4]), do: init(opts, %__MODULE__{stream: Stream.new()})

  defp init([], page), do: page
  defp init([{:size, size} | tail], page), do: init(tail, %{page | size: size})
  defp init([_ | tail], page), do: init(tail, page)

  def push(page, command), do: %{page | stream: Stream.push(page.stream, command)}

  def set_fill_color(page, color) do
    push(page, color_command(color, fill_command(color)))
  end

  def set_stroke_color(page, color) do
    push(page, color_command(color, stroke_command(color)))
  end

  def set_line_width(page, width) do
    push(page, [width, "w"])
  end

  def rectangle(page, {x, y}, {w, h}) do
    push(page, [x, y, w, h, "re"])
  end

  def line(page, {x, y}, {x2, y2}) do
    page
    |> move_to({x, y})
    |> line_append({x2, y2})
  end

  def move_to(page, {x, y}) do
    push(page, [x, y, "m"])
  end

  def line_append(page, {x, y}) do
    push(page, [x, y, "l"])
  end

  def stroke(page) do
    push(page, ["S"])
  end

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

  defp color_command(color_name, command) when is_atom(color_name) do
    color = Pdf.Color.color(color_name)
    color_command(color, command)
  end

  defp color_command({r, g, b}, command) when is_integer(r) and is_integer(g) and is_integer(b) do
    [r / 255.0, g / 255.0, b / 255.0, command]
  end

  defp color_command({r, g, b}, command) when is_float(r) and is_float(g) and is_float(b) do
    [r, g, b, command]
  end

  defp color_command({r, g, b}, command) when is_float(r) and is_float(g) and is_float(b) do
    [r, g, b, command]
  end

  defp color_command({c, m, y, k}, command)
       when is_float(c) and is_float(m) and is_float(y) and is_float(k) do
    [c, m, y, k, command]
  end

  defp fill_command(color_name) when is_atom(color_name), do: "rg"
  defp fill_command({_r, _g, _b}), do: "rg"
  defp fill_command({_c, _m, _y, _k}), do: "k"

  defp stroke_command(color_name) when is_atom(color_name), do: "RG"
  defp stroke_command({_r, _g, _b}), do: "RG"
  defp stroke_command({_c, _m, _y, _k}), do: "K"

  defimpl Pdf.Size do
    def size_of(%Pdf.Page{} = page), do: Pdf.Size.size_of(page.stream)
  end

  defimpl Pdf.Export do
    def to_iolist(%Pdf.Page{} = page), do: Pdf.Export.to_iolist(page.stream)
  end
end
