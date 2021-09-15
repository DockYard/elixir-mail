# Tables

Use `Pdf.table/5` to add a table to your PDF.
This guide explains the different options you can use with the following example, you can see the generated [pdf](assets/table.pdf).

```elixir
data = [
  ["Header 1", "Header 2", "Header 3", "Header 4"],
  ["Col 1,1", "Col 1,2", "Col 1,3", "Col 1,4"],
  ["Col 2,1", "Column 2,2", "Col 2,3", "Col 2,4"],
  [nil, "mmmmmmmmmm", nil, "mmmmmmmmmmm"],
  ["Col 3,1", ["Column ", {"3,2", bold: true}], "Col 3,3", "Col 3,4"],
  ["Col 4,1", "Column 4,2", "Col 4,3", "Col 4,4"],
  [nil, nil, "Col 5,3", "Col 5,4"]
]

{:ok, pdf} = Pdf.new(size: :a4)

table_opts = [
  padding: 2,
  background: :gainsboro,
  repeat_header: 1,
  cols: [
    [width: 100, font_size: 8],
    [],
    [min_width: 30, background: :dark_gray, color: :white],
    [width: 80, align: :right, padding: {2, 4}]
  ],
  rows: %{
    0 => [
      bold: true,
    align: :center,
    kerning: true,
    cols: [
      [colspan: 2]
    ]
    ],
    2 => [background: :silver, cols: [[], [], [background: :dark_green]]],
    -1 => [
      bold: true,
    border: {0.5, 0, 0, 0},
    cols: [
      [background: nil],
      [background: nil],
      [border: {0, 0.5, 0.5, 0.5}],
      [border: {0, 0.5, 0.5, 0.5}, color: :red]
    ]
    ]
  },
border: 0.5
]

pdf
  |> Pdf.set_font("Helvetica", 12)
  |> Pdf.set_fill_color(:black)
  |> Pdf.set_line_cap(:square)
  |> Pdf.set_line_join(:miter)

{pdf, remaining} =
  pdf
  |> Pdf.table({100, 800}, {400, 80}, data, table_opts)

cursor = Pdf.cursor(pdf)

{pdf, :complete} =
  pdf
  |> Pdf.table({100, cursor - 20}, {400, 200}, remaining, table_opts)

pdf
  |> Pdf.cleanup()
```

You can use either `Pdf.table/5` or `Pdf.table!/5` to add a table to your Pdf.

`Pdf.table/5` returns a tuple :

- `{pid, :complete}` All data was processed.
- `{pid, remaining}` Not all data fit into the given dimensions.

  This allows you to draw the remaining data on eg another page.

`Pdf.table!/5` will raise a `RuntimeError` if the data does not fit.

## Options

### General options
These options can be applied to the table, rows and columns.

Options | Explanation
:-----  | :------
`:background` | One of the predefined color atomsi (see `Pdf.Color.color/1`), an RGB tuple or a CMYK tuple.
`:border` | The thickness of the border, see `:padding` below.
`:color` | The font color, accepts the same options as `:background`.
`:font_size` | Font size
`:bold` | `true` or `false`
`:italic` | `true` or `false`
`:padding` | The padding to apply, cfr CSS, can take for all sides `{int}`, `{horizontal, vertical}`, `{top, horizontal, bottom}`, `{top, right, bottom, left}`
`:colspan` | The number of columns to merge together

### Table specific options

Extra Options | Explanation
:------------ | :------
`:cols` | Definitions for the individual columns.
`:repeat_header` | The number of rows that make up the header of the table, and that will be repeated when the data overflows the supplied boundary.
`:rows` | Definitions for the individual rows.
`:encoding_replacement_character` | Supply a character to replace characters that don't match the WIN ANSI encoding
`:allow_row_overflow` | (boolean) If a row can be split when returning {:continue, data}. Needed for when a row content will be longer than a full table height

The headers if set will be repeated with each call.

### Column specific options
`:cols` takes a list of column definitions.

Extra Options | Explanation
:----- | :-----
`:width` | Fixed width
`:max_width` | The maximum column width
`:min_width` | The minimum column width

### Row specific options
`:rows` takes a map of row definitions.
A row definition is a list of attributes, eg. `[background: :silver]` to apply to the given row(s).

- `<row_number>` Definition for row with this number. Valid row numbers are `-number..0..number of rows in data`, eg 0 for the first row, -1 for the last, -2 for the second last, etc. These will take precedence over `:odd` and `:even`.
- `:even` Definition for rows with even numbers, 0,2,4, ...
- `:odd`  Definition for rows with odd numbers, 1,3,5, ...

Extra Options | Explanation
:----- | :-----
`:cols` | Definitions for the columns in this single row
