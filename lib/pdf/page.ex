defmodule Pdf.Page do
  defstruct size: :a4,
            stream: nil,
            fonts: nil,
            current_font: nil,
            current_font_size: 0,
            fill_color: :black,
            leading: nil,
            cursor: 0,
            in_text: false,
            saved: %{},
            saving_state: false

  defdelegate table(page, data, xy, wh), to: Pdf.Table
  defdelegate table(page, data, xy, wh, opts), to: Pdf.Table
  defdelegate table!(page, data, xy, wh), to: Pdf.Table
  defdelegate table!(page, data, xy, wh, opts), to: Pdf.Table

  import Pdf.Utils
  alias Pdf.{Image, Fonts, Stream, Text}

  def new(opts \\ [size: :a4]), do: init(opts, %__MODULE__{stream: Stream.new()})

  defp init([], page), do: page
  defp init([{:fonts, fonts} | tail], page), do: init(tail, %{page | fonts: fonts})

  defp init([{:size, size} | tail], page) do
    [_bottom, _left, _width, height] = Pdf.Paper.size(size)
    init(tail, %{page | size: size, cursor: height})
  end

  defp init([{:compress, false} | tail], page),
    do: init(tail, %{page | stream: Stream.new(compress: false)})

  defp init([{:compress, true} | tail], page),
    do: init(tail, %{page | stream: Stream.new(compress: 6)})

  defp init([{:compress, level} | tail], page),
    do: init(tail, %{page | stream: Stream.new(compress: level)})

  defp init([_ | tail], page), do: init(tail, page)

  def push(page, command), do: %{page | stream: Stream.push(page.stream, command)}

  def set_fill_color(%{fill_color: color} = page, color), do: page

  def set_fill_color(%{saving_state: true} = page, color) do
    push(page, color_command(color, fill_command(color)))
  end

  def set_fill_color(page, color) do
    push(%{page | fill_color: color}, color_command(color, fill_command(color)))
  end

  def set_stroke_color(page, color) do
    push(page, color_command(color, stroke_command(color)))
  end

  def set_line_width(page, width) do
    push(page, [width, "w"])
  end

  def set_line_cap(page, style) do
    push(page, [line_cap(style), "J"])
  end

  defp line_cap(:butt), do: 0
  defp line_cap(:round), do: 1
  defp line_cap(:projecting_square), do: 2
  defp line_cap(:square), do: 2
  defp line_cap(style), do: style

  def set_line_join(page, style) do
    push(page, [line_join(style), "j"])
  end

  defp line_join(:miter), do: 0
  defp line_join(:round), do: 1
  defp line_join(:bevel), do: 2
  defp line_join(style), do: style

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

  def fill(page) do
    push(page, ["f"])
  end

  def set_font(%{fonts: fonts} = page, name, size, opts \\ []) do
    font = Fonts.get_font(fonts, name, opts)
    push_font(page, font, size)
  end

  defp push_font(%{current_font: font, current_font_size: size} = page, font, size), do: page

  defp push_font(%{in_text: true} = page, font, size) do
    push(%{page | current_font: font, current_font_size: size}, [font.name, size, "Tf"])
  end

  defp push_font(page, font, size) do
    %{page | current_font: font, current_font_size: size}
  end

  def set_font_size(page, size) do
    push_font_size(page, size)
  end

  defp push_font_size(%{current_font_size: size} = page, size), do: page

  defp push_font_size(%{in_text: true, current_font: font} = page, size) do
    push(%{page | current_font_size: size}, [font.name, size, "Tf"])
  end

  defp push_font_size(page, size) do
    %{page | current_font_size: size}
  end

  def set_text_leading(page, leading) do
    %{page | leading: leading}
  end

  defp begin_text(%{current_font: font, current_font_size: size} = page) do
    %{page | in_text: true, saved: %{current_font: font, current_font_size: size}}
    |> push(["BT"])
    |> push([font.name, size, "Tf"])
  end

  defp end_text(%{in_text: true, saved: saved} = page) do
    push(
      %{
        page
        | in_text: false,
          current_font: Map.get(saved, :current_font),
          current_font_size: Map.get(saved, :current_font_size),
          saved: %{}
      },
      ["ET"]
    )
  end

  def text_at(page, xy, text, opts \\ [])

  def text_at(page, {x, y}, attributed_text, opts) when is_list(attributed_text) do
    attributed_text = annotate_attributed_text(attributed_text, page, opts)

    page
    |> begin_text()
    |> push([x, y, "Td"])
    |> print_attributed_line(attributed_text)
    |> end_text()
    |> set_cursor(y - line_height(page, attributed_text))
  end

  def text_at(%{current_font: %{module: font}} = page, {x, y}, text, opts) do
    page
    |> begin_text()
    |> push([x, y, "Td"])
    |> push(kerned_text(font, text, Keyword.get(opts, :kerning, false)))
    |> end_text()
  end

  defp merge_same_opts([]), do: []

  defp merge_same_opts([{text, width, opts}, {text2, width2, opts} | tail]) do
    merge_same_opts([{text <> text2, width + width2, opts} | tail])
  end

  defp merge_same_opts([chunk | tail]) do
    [chunk | merge_same_opts(tail)]
  end

  def annotate_attributed_text(nil, page, opts) do
    annotate_attributed_text([""], page, opts)
  end

  def annotate_attributed_text(text, page, opts) when is_binary(text) do
    annotate_attributed_text([text], page, opts)
  end

  def annotate_attributed_text(
        attributed_text,
        %{fonts: fonts, current_font: %{module: font}} = page,
        overall_opts
      )
      when is_list(attributed_text) do
    attributed_text
    |> Enum.map(fn
      str when is_binary(str) -> {str, []}
      {str} -> {str, []}
      {str, opts} -> {str, opts}
      annotated -> annotated
    end)
    |> Enum.map(fn
      {text, width, opts} ->
        {text, width, opts}

      {text, opts} ->
        opts = Keyword.merge(overall_opts, opts)

        font =
          if Enum.any?([:bold, :italic], &Keyword.has_key?(opts, &1)) do
            Fonts.get_font(fonts, font.family_name, Keyword.take(opts, [:bold, :italic]))
          else
            Fonts.get_font(fonts, font.name, [])
          end

        font_size = Keyword.get(opts, :size, page.current_font_size)
        color = Keyword.get(opts, :color, page.fill_color)

        height = font_size
        ascender = font.module.ascender * font_size / 1000
        descender = -(font.module.descender * font_size / 1000)
        cap_height = font.module.cap_height * font_size / 1000
        x_height = font.module.x_height * font_size / 1000
        line_gap = (font_size - (ascender + descender)) / 2

        width = font.module.text_width(text, font_size, opts)

        {text, width,
         Keyword.merge(
           overall_opts,
           Keyword.merge(opts,
             ascender: ascender,
             cap_height: cap_height,
             color: color,
             descender: descender,
             font: font,
             height: height,
             line_gap: line_gap,
             size: font_size,
             x_height: x_height
           )
         )}
    end)
  end

  def annotate_attributed_text(non_string, page, overall_opts) do
    annotate_attributed_text(to_string(non_string), page, overall_opts)
  end

  def text_wrap!(page, xy, wh, text, opts \\ []) do
    case text_wrap(page, xy, wh, text, opts) do
      {page, :complete} -> page
      _ -> raise(RuntimeError, "The supplied text did not fit within the supplied boundary")
    end
  end

  def text_wrap(page, xy, wh, text, opts \\ [])

  def text_wrap(page, {x, :cursor}, wh, text, opts) do
    y = cursor(page)
    text_wrap(page, {x, y}, wh, text, opts)
  end

  def text_wrap(page, {x, y}, {w, h}, text, opts)
      when is_binary(text) do
    text_wrap(page, {x, y}, {w, h}, [text], opts)
  end

  def text_wrap(page, {x, y}, {w, h}, {:continue, [{:line, _line} | _] = lines}, opts) do
    text_wrap(page, {x, y}, {w, h}, lines, opts)
  end

  def text_wrap(page, {x, y}, {w, h}, [{:line, _line} | _] = lines, opts) do
    page
    |> begin_text()
    |> set_cursor(y)
    |> print_attributed_lines(lines, x, y, w, h, opts)
    |> complete_wrapping()
  end

  def text_wrap(page, {x, y}, {w, h}, {:continue, chunks}, opts) do
    page
    |> begin_text()
    |> set_cursor(y)
    |> print_attributed_chunks(chunks, x, y, w, h, opts)
    |> complete_wrapping()
  end

  def text_wrap(page, {x, y}, {w, h}, attributed_text, opts) when is_list(attributed_text) do
    attributed_text = annotate_attributed_text(attributed_text, page, opts)

    chunks = Text.chunk_attributed_text(attributed_text, opts)

    page
    |> begin_text()
    |> set_cursor(y)
    |> print_attributed_chunks(chunks, x, y, w, h, opts)
    |> complete_wrapping()
  end

  def complete_wrapping({page, []}) do
    {end_text(page), :complete}
  end

  def complete_wrapping({page, [_ | _] = remaining}) do
    {end_text(page), {:continue, remaining}}
  end

  defp line_height(page, attributed_text) do
    line_height = attributed_text |> Enum.map(&Keyword.get(elem(&1, 2), :height)) |> Enum.max()
    Enum.max(Enum.filter([page.leading, line_height], & &1))
  end

  defp print_attributed_chunks(page, chunks, x, y, width, height, opts, prev_line_height \\ 0)

  defp print_attributed_chunks(page, [], _, _, _, _, _, _), do: {page, []}

  defp print_attributed_chunks(page, chunks, x, y, width, height, opts, prev_line_height) do
    {line, tail} =
      case Text.wrap_chunks(chunks, width) do
        {[], [line | tail]} ->
          {[line], tail}

        other ->
          other
      end

    line_width = Enum.reduce(line, 0, fn {_, width, _}, acc -> width + acc end)

    line_height =
      page.leading || line |> Enum.map(&Keyword.get(elem(&1, 2), :height)) |> Enum.max()

    if line_height > height do
      # No available vertical space to print the line so return remaining lines
      {page, chunks}
    else
      x_offset =
        case Keyword.get(opts, :align, :left) do
          :left -> x
          :center -> x + (width - line_width) / 2
          :right -> x + (width - line_width)
        end

      ascender =
        line
        |> Enum.map(&Keyword.get(elem(&1, 2), :ascender))
        |> Enum.max()

      line_gap =
        line
        |> Enum.map(&Keyword.get(elem(&1, 2), :line_gap))
        |> Enum.max()

      y_offset = if prev_line_height == 0, do: y - (ascender + line_gap), else: -prev_line_height

      page
      |> push([x_offset, y_offset, "Td"])
      |> print_attributed_line(line)
      |> move_down(line_height)
      |> print_attributed_chunks(
        tail,
        x - x_offset,
        y - line_height,
        width,
        height - line_height,
        opts,
        line_height
      )
    end
  end

  defp print_attributed_lines(page, lines, x, y, width, height, opts, prev_line_height \\ 0)

  defp print_attributed_lines(page, [], _x, _y, _width, _height, _opts, _prev_line_height),
    do: {page, []}

  defp print_attributed_lines(
         page,
         [{:line, line} | lines],
         x,
         y,
         width,
         height,
         opts,
         prev_line_height
       ) do
    line_width = Enum.reduce(line, 0, fn {_, width, _}, acc -> width + acc end)

    line_height =
      page.leading || line |> Enum.map(&Keyword.get(elem(&1, 2), :height)) |> Enum.max()

    if line_height > height do
      # No available vertical space to print the line so return remaining lines
      {page, [line | lines]}
    else
      x_offset =
        case Keyword.get(opts, :align, :left) do
          :left -> x
          :center -> x + (width - line_width) / 2
          :right -> x + (width - line_width)
        end

      ascender =
        line
        |> Enum.map(&Keyword.get(elem(&1, 2), :ascender))
        |> Enum.max()

      line_gap =
        line
        |> Enum.map(&Keyword.get(elem(&1, 2), :line_gap))
        |> Enum.max()

      y_offset = if prev_line_height == 0, do: y - (ascender + line_gap), else: -prev_line_height

      page
      |> push([x_offset, y_offset, "Td"])
      |> print_attributed_line(line)
      |> move_down(line_height)
      |> print_attributed_lines(
        lines,
        x - x_offset,
        y - line_height,
        width,
        height - line_height,
        opts,
        line_height
      )
    end
  end

  defp print_attributed_line(page, attributed_text) do
    attributed_text
    |> merge_same_opts
    |> Enum.reduce(page, fn {text, _width, opts}, page ->
      page
      |> set_font(opts[:font].module.name, opts[:size], opts)
      |> set_fill_color(opts[:color])
      |> push(kerned_text(opts[:font].module, text, Keyword.get(opts, :kerning, false)))
    end)
  end

  def text_lines(page, xy, lines, opts \\ [])

  def text_lines(page, _xy, [], _opts), do: page

  def text_lines(page, {x, y}, lines, opts) do
    leading = page.leading || page.current_font_size

    page
    |> begin_text()
    |> push([x, y, "Td"])
    |> push([leading, "TL"])
    |> draw_lines(lines, opts)
    |> end_text()
  end

  def add_image(page, {x, y}, image, opts \\ []) do
    %{name: image_name, image: %Image{width: width, height: height}} = image
    scaled_width = Keyword.get(opts, :width, width) / width
    scaled_height = Keyword.get(opts, :height, height) / height
    width = Keyword.get(opts, :width, width * scaled_height)
    height = Keyword.get(opts, :height, height * scaled_width)

    page
    |> save_state()
    |> push([width, 0, 0, height, x, y, "cm"])
    |> push([image_name, "Do"])
    |> restore_state()
  end

  def clip(page) do
    push(page, ["W n"])
  end

  def save_state(page) do
    push(%{page | saving_state: true}, "q")
  end

  def restore_state(page) do
    push(%{page | saving_state: false}, "Q")
  end

  def size(%{size: size}) do
    [_bottom, _left, width, height] = Pdf.Paper.size(size)
    %{width: width, height: height}
  end

  def set_cursor(page, y) do
    %{page | cursor: y}
  end

  def move_down(%{cursor: y} = page, amount) do
    %{page | cursor: y - amount}
  end

  def cursor(%{cursor: cursor}) do
    cursor
  end

  defp kerned_text(_font, text, false) do
    [s(Text.normalize_string(Text.escape(text))), "Tj"]
  end

  defp kerned_text(font, text, true) do
    text =
      text
      |> Text.normalize_string()
      |> font.kern_text()
      |> Text.escape()
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

  defimpl Inspect do
    def inspect(%Pdf.Page{size: size}, _opts), do: "#Page<size: #{inspect(size)}>"
  end
end
