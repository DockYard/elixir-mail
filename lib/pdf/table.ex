defmodule Pdf.Table do
  alias Pdf.{Page, Text}

  def table(page, xy, wh, data, opts \\ [])

  def table(page, _xy, _wh, [], _opts), do: {page, []}

  def table(page, {x, y}, {w, h}, {:continue, data}, opts) do
    case draw_table(page, {x, y}, {w, h}, data, opts) do
      {page, []} ->
        {page, []}

      {page, remaining} ->
        repeat_rows = Keyword.get(opts, :repeat_header, 0)
        {page, {:continue, Enum.take(data, repeat_rows) ++ remaining}}
    end
  end

  def table(page, {x, y}, {w, h}, data, opts) do
    [first_row | _] = data
    num_cols = length(first_row)

    {opts, col_opts} = fix_column_options(num_cols, opts)

    data =
      data
      |> chunk_data(page, opts, Keyword.get(opts, :rows, %{}))
      |> set_col_dimensions({x, y}, {w, h}, col_opts)

    table(page, {x, y}, {w, h}, {:continue, data}, opts)
  end

  defp set_col_dimensions(data, {x, _y}, {width, _height}, col_opts) do
    widths =
      data
      |> calculate_widths()
      |> Enum.zip(Enum.map(col_opts, &Keyword.get(&1, :width)))
      |> Enum.zip(col_opts)
      |> Enum.map(fn
        {{flex_width, width}, col_opts} ->
          min_width = Keyword.get(col_opts, :min_width)
          max_width = Keyword.get(col_opts, :max_width)
          {flex_width, width, min_width, max_width}
      end)
      # First pass makes min/max width adjustments
      |> calculate_dimensions(width)
      # Second pass resizes cols without min/max widths
      |> calculate_dimensions(width)
      |> Enum.map(fn
        {width, nil, _, _} -> width
        {_, width, _, _} -> width
      end)

    # Make sure the total width distribution matches the expected width
    total_calculated = Enum.reduce(widths, 0, &(&1 + &2))

    widths =
      if total_calculated != width do
        Enum.map(widths, &(&1 / total_calculated * width))
      else
        widths
      end

    data
    |> set_widths(widths, x)
    |> set_spanning()
  end

  defp set_spanning([]), do: []

  defp set_spanning([row | rows]) do
    [span_cols(row) | set_spanning(rows)]
  end

  defp span_cols([]), do: []

  defp span_cols([{_content, col_opts} | _] = cols) do
    case Enum.split(cols, Keyword.get(col_opts, :colspan, 1)) do
      {[col], cols} ->
        [col | span_cols(cols)]

      {[{content, col_opts} | _tail] = spanned, cols} ->
        spanned_width =
          Enum.reduce(spanned, 0, fn {_, col_opts}, acc ->
            Keyword.get(col_opts, :width, 0) + acc
          end)

        [{content, Keyword.put(col_opts, :width, spanned_width)} | span_cols(cols)]
    end
  end

  defp calculate_dimensions(widths, width) do
    total_fixed =
      Enum.reduce(widths, 0, fn
        {_, nil, _, _}, acc -> acc
        {_, width, _, _}, acc -> width + acc
      end)

    available_width = width - total_fixed

    total_flexible =
      Enum.reduce(widths, 0, fn
        {width, nil, _, _}, acc -> width + acc
        _, acc -> acc
      end)

    widths
    |> Enum.map(fn
      {width, nil, min_width, max_width} ->
        calculated_width = width / total_flexible * available_width

        adjusted_width =
          if min_width && min_width > calculated_width, do: min_width, else: calculated_width

        adjusted_width =
          if max_width && max_width < adjusted_width, do: max_width, else: adjusted_width

        if adjusted_width != calculated_width do
          {width, adjusted_width, min_width, max_width}
        else
          {calculated_width, nil, nil, nil}
        end

      width ->
        width
    end)
  end

  defp set_widths([], _widths, _x), do: []

  defp set_widths([row | rows], widths, x) do
    {row, _} =
      row
      |> Enum.zip(widths)
      |> Enum.map_reduce(x, fn {{col, col_opts}, width}, x ->
        {{col, Keyword.merge(col_opts, width: width, x: x)}, x + width}
      end)

    [row | set_widths(rows, widths, x)]
  end

  defp chunk_data(data, page, opts, row_opts) do
    row_count = length(data)

    row_opts =
      Enum.map(row_opts, fn
        {neg_idx, opts} when neg_idx < 0 -> {row_count + neg_idx, opts}
        {idx, opts} -> {idx, opts}
      end)
      |> Map.new()

    chunk_rows(data, 0, page, opts, row_opts)
  end

  defp chunk_rows([], _row_index, _page, _opts, _row_opts), do: []

  defp chunk_rows([row | rows], row_index, page, opts, row_opts) do
    row =
      merge_col_opts(row, Keyword.get(opts, :cols, []), opts, Map.get(row_opts, row_index, []))

    [chunk_cols(row, page) | chunk_rows(rows, row_index + 1, page, opts, row_opts)]
  end

  defp chunk_cols([], _page), do: []

  defp chunk_cols([col | cols], page) do
    [chunk_col(col, page) | chunk_cols(cols, page)]
  end

  defp chunk_col({content, col_opts}, page) do
    chunked =
      content
      |> Page.annotate_attributed_text(page, col_opts)
      |> Text.chunk_attributed_text(col_opts)

    {chunked, col_opts}
  end

  defp fix_column_options(num_cols, opts) do
    col_opts = Keyword.get(opts, :cols, [])
    num_col_opts = length(col_opts)

    col_opts =
      if num_col_opts >= num_cols do
        col_opts
      else
        col_opts ++ Enum.map(1..(num_cols - num_col_opts), fn _ -> [] end)
      end

    {Keyword.put(opts, :cols, col_opts), col_opts}
  end

  defp merge_col_opts(cols, col_opts, opts, row_opts) do
    {row_opts, row_col_opts} = fix_column_options(length(cols), row_opts)

    row_opts = Keyword.drop(row_opts, [:cols])

    [cols, col_opts, row_col_opts]
    |> Enum.zip()
    |> Enum.map(fn {col, col_opts, row_col_opts} ->
      col_opts =
        opts
        |> Keyword.drop([:cols, :rows])
        |> Keyword.merge(col_opts)
        |> Keyword.merge(row_opts)
        |> Keyword.merge(row_col_opts)

      {col, col_opts}
    end)
  end

  defp calculate_widths(data) do
    data
    |> Enum.map(fn row ->
      row
      |> Enum.map(fn
        {[], _col_opts} ->
          0

        {col, _col_opts} ->
          col
          |> Enum.map(fn {_, width, col_opts} ->
            {_, pr, _, pl} = padding(col_opts)
            width + pr + pl
          end)
          |> Enum.max()
      end)
    end)
    |> List.zip()
    # TODO: I don't know how efficient it is to work with tuples and back to lists
    #   It may be good to do a zip/1 that returns a list of lists again
    |> Enum.map(&Tuple.to_list/1)
    |> Enum.map(&Enum.max/1)
  end

  defp draw_table(page, _xy, _wh, [], _opts), do: {page, []}

  defp draw_table(page, {x, y}, {w, h}, [head | tail], opts) do
    row =
      head
      |> Enum.map(fn {col, col_opts} ->
        {_, pr, _, pl} = padding(col_opts)
        width = Keyword.get(col_opts, :width) - pr - pl

        lines = Text.wrap_all_chunks(col, width)

        height =
          Enum.reduce(lines, 0, fn line, acc ->
            Enum.max(Enum.map(line, &Keyword.get(elem(&1, 2), :height))) + acc
          end)

        {lines, Keyword.put(col_opts, :height, height)}
      end)

    row_height = Enum.map(row, &col_height/1) |> Enum.max()

    if row_height > h do
      {page, [head | tail]}
    else
      page =
        page
        |> draw_row(y - row_height, row_height, row)
        |> Page.set_cursor(y - row_height)

      draw_table(page, {x, y - row_height}, {w, h - row_height}, tail, opts)
    end
  end

  defp draw_row(page, _y, _row_height, []), do: page

  defp draw_row(page, y, row_height, [{lines, col_opts} | tail]) do
    {pt, pr, pb, pl} = padding(col_opts)
    width = Keyword.get(col_opts, :width)
    x = Keyword.get(col_opts, :x)

    {page, []} =
      page
      |> draw_background(lines, {x, y}, {width, row_height}, background(col_opts))
      |> Page.save_state()
      |> clip({x + pl, y + pb}, {width - pl - pr, row_height - pt - pb})
      |> Page.text_wrap(
        {x + pl, y + row_height - pt},
        {width - pl - pr, row_height},
        lines,
        col_opts
      )

    page
    |> Page.restore_state()
    |> draw_border({x, y}, {width, row_height}, border(col_opts))
    |> draw_row(y, row_height, tail)
  end

  defp draw_background(page, _lines, _xy, _wh, nil), do: page

  defp draw_background(page, _lines, {x, y}, {w, h}, color) do
    page
    |> Page.save_state()
    |> Page.rectangle({x, y}, {w, h})
    |> Page.set_fill_color(color)
    |> Page.fill()
    |> Page.restore_state()
  end

  defp clip(page, {x, y}, {w, h}) do
    page
    |> Page.rectangle({x, y}, {w, h})
    |> Page.clip()
  end

  defp draw_border(page, {x, y}, {w, h}, {bt, br, bb, bl} = border) do
    page
    |> draw_top_border({x, y}, {w, h}, bt)
    |> draw_right_border({x, y}, {w, h}, br)
    |> draw_bottom_border({x, y}, {w, h}, bb)
    |> draw_left_border({x, y}, {w, h}, bl)
    |> stroke_border(border)
  end

  defp stroke_border(page, {0, 0, 0, 0}), do: page
  defp stroke_border(page, _border), do: Page.stroke(page)

  defp draw_top_border(page, _xy, _wh, 0), do: page

  defp draw_top_border(page, {x, y}, {w, h}, width) do
    page
    |> Page.set_line_width(width)
    |> Page.line({x, y + h}, {x + w, y + h})
  end

  defp draw_right_border(page, _xy, _wh, 0), do: page

  defp draw_right_border(page, {x, y}, {w, h}, width) do
    page
    |> Page.set_line_width(width)
    |> Page.line({x + w, y + h}, {x + w, y})
  end

  defp draw_bottom_border(page, _xy, _wh, 0), do: page

  defp draw_bottom_border(page, {x, y}, {w, _h}, width) do
    page
    |> Page.set_line_width(width)
    |> Page.line({x, y}, {x + w, y})
  end

  defp draw_left_border(page, _xy, _wh, 0), do: page

  defp draw_left_border(page, {x, y}, {_w, h}, width) do
    page
    |> Page.set_line_width(width)
    |> Page.line({x, y + h}, {x, y})
  end

  defp col_height({_, col_opts}) do
    {pt, _pr, pb, _pl} = padding(col_opts)
    height = Keyword.get(col_opts, :height)
    height + pt + pb
  end

  defp col_height({_, _, col_opts}) do
    {pt, _pr, pb, _pl} = padding(col_opts)
    height = Keyword.get(col_opts, :height)
    height + pt + pb
  end

  defp padding(nil), do: {0, 0, 0, 0}
  defp padding(opts) when is_list(opts), do: padding(Keyword.get(opts, :padding, 0))
  defp padding(p) when is_number(p), do: {p, p, p, p}
  defp padding({p}) when is_number(p), do: {p, p, p, p}
  defp padding({py, px}), do: {py, px, py, px}
  defp padding({pt, px, pb}), do: {pt, px, pb, px}
  defp padding({pt, pr, pb, pl}), do: {pt, pr, pb, pl}

  defp border(nil), do: {0, 0, 0, 0}
  defp border(opts) when is_list(opts), do: border(Keyword.get(opts, :border, 0))
  defp border(b) when is_number(b), do: {b, b, b, b}
  defp border({b}) when is_number(b), do: {b, b, b, b}
  defp border({by, bx}), do: {by, bx, by, bx}
  defp border({bt, bx, bb}), do: {bt, bx, bb, bx}
  defp border({bt, br, bb, bl}), do: {bt, br, bb, bl}

  defp background(opts) when is_list(opts), do: Keyword.get(opts, :background)
end
