defmodule Pdf.Page do
  defstruct size: :a4,
            stream: nil,
            fonts: nil,
            current_font: nil,
            current_font_size: 0,
            fill_color: :black,
            leading: nil

  import Pdf.Utils
  alias Pdf.{Image, Fonts, Stream, Text}

  def new(opts \\ [size: :a4]), do: init(opts, %__MODULE__{stream: Stream.new()})

  defp init([], page), do: page
  defp init([{:fonts, fonts} | tail], page), do: init(tail, %{page | fonts: fonts})

  defp init([{:size, size} | tail], page), do: init(tail, %{page | size: size})

  defp init([{:compress, true} | tail], page),
    do: init(tail, %{page | stream: Stream.new(compress: 6)})

  defp init([{:compress, level} | tail], page),
    do: init(tail, %{page | stream: Stream.new(compress: level)})

  defp init([_ | tail], page), do: init(tail, page)

  def push(page, command), do: %{page | stream: Stream.push(page.stream, command)}

  def set_fill_color(%{fill_color: color} = page, color), do: page

  def set_fill_color(page, color) do
    push(%{page | fill_color: color}, color_command(color, fill_command(color)))
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

  def set_font(%{fonts: fonts} = page, name, size, opts \\ []) do
    font = Fonts.get_font(fonts, name, opts)

    if page.current_font == font && page.current_font_size == size do
      page
    else
      push(%{page | current_font: font, current_font_size: size}, [font.name, size, "Tf"])
    end
  end

  def set_text_leading(page, leading) do
    %{page | leading: leading}
  end

  def text_at(page, xy, text, opts \\ [])

  def text_at(page, {x, y}, attributed_text, opts) when is_list(attributed_text) do
    attributed_text = annotate_attributed_text(attributed_text, page, opts)

    page =
      page
      |> push("BT")
      |> push([x, y, "Td"])

    page =
      attributed_text
      |> Enum.reduce(page, fn {text, opts}, page ->
        page
        |> set_font(opts[:font].module.name, opts[:size], opts)
        |> set_fill_color(opts[:color])
        |> push(kerned_text(opts[:font], text, Keyword.get(opts, :kerning, false)))
        |> push([opts[:width], 0, "TD"])
      end)

    # |> push(kerned_text(font, text, Keyword.get(opts, :kerning, false)))
    page
    |> push("ET")
  end

  def text_at(%{current_font: %{module: font}} = page, {x, y}, text, opts) do
    page
    |> push("BT")
    |> push([x, y, "Td"])
    |> push(kerned_text(font, text, Keyword.get(opts, :kerning, false)))
    |> push("ET")
  end

  defp annotate_attributed_text(
         attributed_text,
         %{fonts: fonts, current_font: %{module: font}} = page,
         overall_opts
       ) do
    attributed_text
    |> Enum.map(fn
      str when is_binary(str) -> {str, []}
      {str} -> {str, []}
      {str, opts} -> {str, opts}
    end)
    |> Enum.map(fn {text, opts} ->
      font = Fonts.get_font(fonts, font.family_name, Keyword.take(opts, [:bold, :italic]))
      font_size = Keyword.get(opts, :size, page.current_font_size)
      color = Keyword.get(opts, :color, page.fill_color)

      height = font_size
      ascender = font.module.ascender * font_size / 1000

      width = font.module.text_width(text, font_size, opts)

      {text,
       Keyword.merge(
         overall_opts,
         Keyword.merge(opts,
           ascender: ascender,
           color: color,
           font: font,
           height: height,
           size: font_size,
           width: width
         )
       )}
    end)
  end

  def text_wrap(%{current_font: %{module: font}} = page, {x, y}, {w, h}, text, opts \\ []) do
    top_offset = font.ascender * page.current_font_size / 1000
    text_chunks = Text.wrap(font, page.current_font_size, text, w, opts)

    text_lines(page, {x, y + h - top_offset}, text_chunks, opts)
  end

  def text_lines(page, {x, y}, lines, opts \\ []) do
    leading = page.leading || page.current_font_size

    page
    |> push("BT")
    |> push([x, y, "Td"])
    |> push([leading, "TL"])
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
    [s(Text.normalize_string(text)), "Tj"]
  end

  defp kerned_text(font, text, true) do
    text =
      text
      |> Text.normalize_string()
      |> font.kern_text()
      |> Enum.map(fn
        str when is_binary(str) -> s(str)
        num -> num
      end)

    [Pdf.Array.new(text), "TJ"]
  end

  defp draw_lines(%{current_font: %{module: font}} = page, [line], opts) do
    push(page, kerned_text(font, line, Keyword.get(opts, :kerning, false)))
  end

  defp draw_lines(%{current_font: %{module: font}} = page, [line | tail], opts) do
    text = kerned_text(font, line, Keyword.get(opts, :kerning, false))
    draw_lines(push(page, text ++ ["T*"]), tail, opts)
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
