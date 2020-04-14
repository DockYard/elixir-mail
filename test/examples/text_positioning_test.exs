defmodule Pdf.Examples.TextPositioningTest do
  use Pdf.Case, async: true

  @open false
  test "" do
    file_path = output("text_positioning.pdf")

    {:ok, pdf} = Pdf.new(size: :a4, compress: false)

    %{width: width, height: height} = Pdf.size(pdf)

    pdf
    |> Pdf.set_line_width(0.5)
    |> Pdf.set_stroke_color(:gray)
    |> Pdf.set_fill_color(:black)
    |> Pdf.line({20, height - 100}, {width - 40, height - 100})
    |> Pdf.stroke()
    |> Pdf.set_font("Helvetica", 10)
    |> Pdf.text_at({20, height - 100}, "This should write on the line")
    # Text wrap is calculated from top left (because it needs to write down until it runs out of space)
    |> Pdf.text_wrap!({200, height - 100}, {200, 10}, "This should write under the line")
    # The rectangle is drawn from bottom left
    |> Pdf.rectangle({200, height - 100 - 10}, {200, 10})
    |> Pdf.stroke()
    |> Pdf.write_to(file_path)
    |> Pdf.delete()

    if @open, do: System.cmd("open", ["-g", file_path])
  end
end
