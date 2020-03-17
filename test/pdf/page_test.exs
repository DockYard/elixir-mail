defmodule Pdf.PageTest do
  use ExUnit.Case, async: true

  alias Pdf.{Page, Fonts, ObjectCollection}

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

  describe "set_fill_color/2" do
    test "it sets the fill color", %{page: page} do
      page = Page.set_fill_color(page, :red)
      assert page.fill_color == :red
      assert export(page) == "1.0 0.0 0.0 rg\n"
    end

    test "it doesn't log a repeat command", %{page: page} do
      page = Page.set_fill_color(page, :red)
      page = Page.set_fill_color(page, :red)
      assert page.fill_color == :red
      assert export(page) == "1.0 0.0 0.0 rg\n"
    end
  end

  describe "text operations" do
    test "automatically wrapping text commands within BT and ET", %{page: page} do
      page = Page.set_font(page, "Helvetica", 12)
      page = Page.text_at(page, {10, 20}, "Hello world")

      assert export(page) ==
               """
               /F1 12 Tf
               BT
               10 20 Td
               (Hello world) Tj
               ET
               """
    end
  end

  describe "text_at/4" do
    test "accepts a string", %{page: page} do
      page = Page.set_font(page, "Helvetica", 12)
      page = Page.text_at(page, {10, 20}, "Hello world")

      assert export(page) ==
               """
               /F1 12 Tf
               BT
               10 20 Td
               (Hello world) Tj
               ET
               """
    end

    test "accepts attributed text", %{page: page} do
      page = Page.set_font(page, "Helvetica", 12)

      page =
        Page.text_at(page, {10, 20}, [
          "Hello ",
          {"world: ", color: :red, bold: true},
          {"foo, ", size: 14},
          {"bar, ", italic: true},
          {"baz"}
        ])

      assert export(page) == """
             /F1 12 Tf
             BT
             10 20 Td
             (Hello ) Tj
             /F2 12 Tf
             1.0 0.0 0.0 rg
             (world: ) Tj
             /F1 14 Tf
             0.0 0.0 0.0 rg
             (foo, ) Tj
             /F3 12 Tf
             (bar, ) Tj
             /F1 12 Tf
             (baz) Tj
             ET
             """
    end
  end

  describe "text_wrap/5" do
    test "with text", %{page: page} do
      page = Page.set_font(page, "Helvetica", 10)
      assert {page, ""} = Page.text_wrap(page, {10, 20}, {200, 100}, "Hello world")

      assert export(page) == """
             /F1 10 Tf
             BT
             10 110 Td
             (Hello world) Tj
             ET
             """
    end

    test "with text, aligned: right", %{page: page} do
      page = Page.set_font(page, "Helvetica", 10)
      assert {page, ""} = Page.text_wrap(page, {10, 20}, {200, 100}, "Hello world", align: :right)

      assert export(page) == """
             /F1 10 Tf
             BT
             160.55 110 Td
             (Hello world) Tj
             ET
             """
    end

    test "with text, aligned: center", %{page: page} do
      page = Page.set_font(page, "Helvetica", 10)

      assert {page, ""} =
               Page.text_wrap(page, {10, 20}, {200, 100}, "Hello world", align: :center)

      assert export(page) == """
             /F1 10 Tf
             BT
             85.275 110 Td
             (Hello world) Tj
             ET
             """
    end

    test "it returns the text that didn't fit", %{page: page} do
      page = Page.set_font(page, "Helvetica", 10)

      assert {page,
              "adipiscing elit. Suspendisse elementum enimmetus, quis posuere sem molestie interdum. Ut efficitur odio lectus, ut facilisis odio tempor quis."} =
               Page.text_wrap(
                 page,
                 {10, 20},
                 {200, 10},
                 "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Suspendisse elementum enim metus, quis posuere sem molestie interdum. Ut efficitur odio lectus, ut facilisis odio tempor quis."
               )

      assert export(page) == """
             /F1 10 Tf
             BT
             10 20 Td
             (Lorem ipsum dolor sit amet, consectetur) Tj
             ET
             """
    end

    test "with attributed text", %{page: page} do
      page = Page.set_font(page, "Helvetica", 12)

      attributed_text = [
        {"Lorem ipsum dolor ", size: 10},
        {"sit amet, ", italic: true},
        {"consectetur adipiscing elit. ", color: :blue},
        "Ut ut enim",
        {"commodo diam ", bold: true, italic: true, size: 10},
        {"lobortis efficitur. ", color: :red},
        {"Curabitur tempor aliquam nulla, vitae cursus purus iaculis vitae.", size: 8}
      ]

      assert {page, []} = Page.text_wrap(page, {10, 20}, {200, 100}, attributed_text)

      assert export(page) == """
             /F1 12 Tf
             BT
             10 108 Td
             /F1 10 Tf
             (Lorem ipsum dolor ) Tj
             /F3 12 Tf
             (sit amet, ) Tj
             /F1 12 Tf
             0.0 0.0 1.0 rg
             (consectetur) Tj
             0 -12 Td
             (adipiscing elit. ) Tj
             0.0 0.0 0.0 rg
             (Ut ut enim) Tj
             /F4 10 Tf
             (commodo) Tj
             0 -12 Td
             (diam ) Tj
             /F1 12 Tf
             1.0 0.0 0.0 rg
             (lobortis efficitur. ) Tj
             /F1 8 Tf
             0.0 0.0 0.0 rg
             (Curabitur tempor) Tj
             0 -8 Td
             (aliquam nulla, vitae cursus purus iaculis vitae.) Tj
             ET
             """
    end
  end

  defp export(%{stream: stream}) do
    (stream
     |> Pdf.Export.to_iolist()
     |> Pdf.Export.to_iolist()
     |> IO.chardata_to_string()
     |> String.split("\n")
     |> Enum.drop_while(&(&1 != "stream"))
     |> Enum.drop(1)
     |> Enum.take_while(&(&1 != "endstream"))
     |> Enum.join("\n")) <> "\n"
  end
end
