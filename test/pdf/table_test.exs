defmodule Pdf.TableTest do
  use Pdf.Case, async: true

  alias Pdf.{Page, ObjectCollection, Fonts}

  setup do
    {:ok, collection} = ObjectCollection.start_link()
    {:ok, fonts} = Fonts.start_link(collection)
    page = Page.new(fonts: fonts, compress: false)

    # Preload fonts so the internal names are fixed (but don't save the resulting stream)
    page
    |> Page.set_font("Helvetica", 12)
    |> Page.set_font("Helvetica", 12, bold: true)
    |> Page.set_font("Helvetica", 12, italic: true)
    |> Page.set_font("Helvetica", 12, bold: true, italic: true)

    {:ok, page: page}
  end

  test "it does nothing with an empty data list", %{page: page} do
    {page, []} = Page.table(page, {20, 600}, {500, 500}, [])

    assert export(page) == "\n"
  end

  test "", %{page: page} do
    data = [
      ["Col 1,1", "Col 1,2", "Col 1,3"],
      ["Col 2,1", "Col 2,2", "Col 2,3"]
    ]

    {page, []} =
      page
      |> Page.set_font("Helvetica", 12)
      |> Page.table({20, 600}, {300, 500}, data)

    assert export(page) == """
           q
           20 588 100.0 12 re
           W n
           BT
           /F1 12 Tf
           20 590.934 Td
           (Col 1,1) Tj
           ET
           Q
           q
           120.0 588 100.0 12 re
           W n
           BT
           /F1 12 Tf
           120.0 590.934 Td
           (Col 1,2) Tj
           ET
           Q
           q
           220.0 588 100.0 12 re
           W n
           BT
           /F1 12 Tf
           220.0 590.934 Td
           (Col 1,3) Tj
           ET
           Q
           q
           20 576 100.0 12 re
           W n
           BT
           /F1 12 Tf
           20 578.934 Td
           (Col 2,1) Tj
           ET
           Q
           q
           120.0 576 100.0 12 re
           W n
           BT
           /F1 12 Tf
           120.0 578.934 Td
           (Col 2,2) Tj
           ET
           Q
           q
           220.0 576 100.0 12 re
           W n
           BT
           /F1 12 Tf
           220.0 578.934 Td
           (Col 2,3) Tj
           ET
           Q
           """
  end
end
