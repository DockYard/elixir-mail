defmodule Pdf.Examples.TableTest do
  use Pdf.Case, async: true

  @open false
  test "" do
    data = [
      ["Header 1", "Header 2", "Header 3", "Header 4"],
      ["Col 1,1", "Col 1,2", "Col 1,3", "Col 1,4"],
      ["Col 2,1", "Column 2,2", "Col 2,3", "Col 2,4"],
      [nil, "mmmmmmmmmm", nil, "mmmmmmmmmmm"],
      ["Col 3,1", ["Column ", {"3,2", bold: true}], "Col 3,3", "Col 3,4"],
      ["Col 4,1", "Column 4,2", "Col 4,3", "Col 4,4"],
      [nil, nil, "Col 5,3", "Col 5,4"]
    ]

    file_path = output("table.pdf")

    {:ok, pdf} = Pdf.new(size: :a4, compress: false)

    table_opts = [
      padding: 2,
      background: :gainsboro,
      repeat_header: 1,
      italic: true,
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
    |> Pdf.write_to(file_path)
    |> Pdf.delete()

    if @open, do: System.cmd("open", ["-g", file_path])
  end
end
