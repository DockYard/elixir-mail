defmodule PdfTest do
  use Pdf.Case, async: true
  doctest Pdf

  @open false
  test "new/1" do
    file_path = output("qtest.pdf")

    Pdf.build([size: :a4, compress: false], fn pdf ->
      pdf
      |> Pdf.set_info(
        title: "Test Document",
        producer: "Test producer",
        creator: "Test Creator",
        created: ~D"2018-05-22",
        modified: ~D"2018-05-22",
        keywords: "word word word",
        author: "Test Author",
        subject: "Test Subject"
      )
      |> Pdf.set_font("Helvetica", 12)
      |> Pdf.text_at({10, 400}, "Hello World😃", encoding_replacement_character: "")
      |> Pdf.text_lines({10, 300}, [
        "First line å",
        "Second line ä",
        "Third line ö"
      ])
      |> Pdf.text_lines(
        {300, 300},
        [
          "Kerned First line å",
          "Kerned Second line ä",
          "Kerned Third line ö"
        ],
        kerning: true
      )
      |> Pdf.text_lines({200, 300}, ["smile😀"], encoding_replacement_character: "")
      |> Pdf.add_image({25, 50}, fixture("rgb.jpg"))
      |> Pdf.add_image({175, 50}, fixture("cmyk.jpg"))
      |> Pdf.add_image({325, 50}, fixture("grayscale.jpg"))
      |> Pdf.add_image({200, 450}, fixture("grayscale.png"))
      |> Pdf.add_image({310, 450}, fixture("truecolour.png"))
      |> Pdf.add_image({420, 450}, {:binary, File.read!(fixture("indexed.png"))})
      |> Pdf.rectangle({200, 365}, {100, 75})
      |> Pdf.set_fill_color(:red)
      |> Pdf.fill()
      |> Pdf.add_image({200, 365}, fixture("grayscale-alpha.png"))
      |> Pdf.rectangle({310, 365}, {100, 75})
      |> Pdf.fill()
      |> Pdf.set_fill_color(:black)
      |> Pdf.add_image({310, 365}, fixture("truecolour-alpha.png"))
      |> Pdf.add_font("test/fonts/Verdana-Bold.afm")
      |> Pdf.set_font("Verdana-Bold", 28)
      |> Pdf.text_at({120.070, 762.653}, "External fonts work")
      |> Pdf.set_font("Helvetica", 28)
      |> Pdf.text_at({200, 230}, "Back to Helvetica")
      |> Pdf.set_font("Helvetica", size: 16, bold: true)
      |> test_normalize_unicode()
      |> Pdf.set_font("Helvetica", 10)
      |> all_win_ansi_chars({10, 180})
      |> Pdf.set_fill_color(:red)
      |> Pdf.text_at({50, 720}, "A string without kerning: VA")
      |> Pdf.set_fill_color({0.5, 0.0, 0.5})
      |> Pdf.text_at({50, 710}, "A string with kerning: VA", kerning: true)
      |> Pdf.set_fill_color({0.5, 0.0, 0.5, 0.5})
      |> Pdf.text_at({50, 680}, "String coloured with CMYK")
      |> Pdf.set_line_width(2)
      |> Pdf.set_stroke_color(:blue)
      |> Pdf.rectangle({20, 550}, {200, 100})
      |> Pdf.stroke()
      |> Pdf.set_line_width(0.5)
      |> Pdf.line({20, 550}, {220, 650})
      |> Pdf.move_to({220, 550})
      |> Pdf.line_append({20, 650})
      |> Pdf.stroke()
      |> Pdf.rectangle({250, 550}, {200, 100})
      |> Pdf.set_stroke_color(:gray)
      |> Pdf.stroke()
      |> Pdf.set_fill_color(:black)
      |> Pdf.set_text_leading(14)
      |> Pdf.text_wrap(
        {250, 650},
        {200, 100},
        "Lorem ipsum dolor sit amet, consectetur\u00A0adipiscing elit. Nullam posuere-nibh consectetur, ullamcorper lorem vel, blandit est. Phasellus ut venenatis odio. Pellentesque eget venenatis dolor.\nUt mattis dui id nulla porta, sit amet congue lacus blandit.😁",
        align: :center,
        encoding_replacement_character: ""
      )
      |> elem(0)
      |> Pdf.set_text_leading(10)
      |> Pdf.text_wrap(
        {50, 500},
        {100, 100},
        [
          {"Lorem "},
          {"ipsum dolor ", bold: true, size: 12},
          {"sit amet", color: :red},
          {", consectetur ", italic: true, size: 14},
          {"adipiscing elit", bold: true, italic: true}
        ],
        align: :right
      )
      |> elem(0)
      |> Pdf.write_to(file_path)
    end)

    if @open, do: System.cmd("open", ["-g", file_path])
  end

  if Kernel.function_exported?(:unicode, :characters_to_nfc_binary, 1) do
    defp test_normalize_unicode(pdf) do
      Pdf.text_at(
        pdf,
        {200, 200},
        "Normalize unicode characters:a\u0300e\u0301i\u0302o\u0303u\u0308"
      )
    end
  else
    defp test_normalize_unicode(pdf) do
      Pdf.text_at(pdf, {200, 200}, "Normalize unicode characters: Only from OTP 20.0")
    end
  end

  defp all_win_ansi_chars(pdf, offset) do
    strings = [
      <<0x0000::utf8, 0x0001::utf8, 0x0002::utf8, 0x0003::utf8, 0x0004::utf8, 0x0005::utf8,
        0x0006::utf8, 0x0007::utf8, 0x0008::utf8, 0x0009::utf8, 0x000A::utf8, 0x000B::utf8,
        0x000C::utf8, 0x000D::utf8, 0x000E::utf8, 0x000F::utf8, 0x0010::utf8, 0x0011::utf8,
        0x0012::utf8, 0x0013::utf8, 0x0014::utf8, 0x0015::utf8, 0x0016::utf8, 0x0017::utf8,
        0x0018::utf8, 0x0019::utf8, 0x001A::utf8, 0x001B::utf8, 0x001C::utf8, 0x001D::utf8,
        0x001E::utf8, 0x001F::utf8, 0x0020::utf8, 0x0021::utf8, 0x0022::utf8, 0x0023::utf8,
        0x0024::utf8, 0x0025::utf8, 0x0026::utf8, 0x0027::utf8, 0x0028::utf8, 0x0029::utf8,
        0x002A::utf8, 0x002B::utf8, 0x002C::utf8, 0x002D::utf8, 0x002E::utf8, 0x002F::utf8,
        0x0030::utf8, 0x0031::utf8, 0x0032::utf8, 0x0033::utf8, 0x0034::utf8, 0x0035::utf8,
        0x0036::utf8, 0x0037::utf8, 0x0038::utf8, 0x0039::utf8, 0x003A::utf8, 0x003B::utf8,
        0x003C::utf8, 0x003D::utf8, 0x003E::utf8, 0x003F::utf8, 0x0040::utf8, 0x0041::utf8,
        0x0042::utf8, 0x0043::utf8, 0x0044::utf8, 0x0045::utf8, 0x0046::utf8, 0x0047::utf8,
        0x0048::utf8, 0x0049::utf8, 0x004A::utf8, 0x004B::utf8, 0x004C::utf8, 0x004D::utf8,
        0x004E::utf8, 0x004F::utf8, 0x0050::utf8, 0x0051::utf8, 0x0052::utf8, 0x0053::utf8,
        0x0054::utf8, 0x0055::utf8, 0x0056::utf8, 0x0057::utf8, 0x0058::utf8, 0x0059::utf8,
        0x005A::utf8, 0x005B::utf8, 0x005C::utf8, 0x005D::utf8, 0x005E::utf8, 0x005F::utf8,
        0x0060::utf8, 0x0061::utf8>>,
      <<0x0062::utf8, 0x0063::utf8, 0x0064::utf8, 0x0065::utf8, 0x0066::utf8, 0x0067::utf8,
        0x0068::utf8, 0x0069::utf8, 0x006A::utf8, 0x006B::utf8, 0x006C::utf8, 0x006D::utf8,
        0x006E::utf8, 0x006F::utf8, 0x0070::utf8, 0x0071::utf8, 0x0072::utf8, 0x0073::utf8,
        0x0074::utf8, 0x0075::utf8, 0x0076::utf8, 0x0077::utf8, 0x0078::utf8, 0x0079::utf8,
        0x007A::utf8, 0x007B::utf8, 0x007C::utf8, 0x007D::utf8, 0x007E::utf8, 0x20AC::utf8,
        0x201A::utf8, 0x0192::utf8, 0x201E::utf8, 0x2026::utf8, 0x2020::utf8, 0x2021::utf8,
        0x02C6::utf8, 0x2030::utf8, 0x0160::utf8, 0x2039::utf8, 0x0152::utf8, 0x017D::utf8,
        0x2018::utf8, 0x2019::utf8, 0x201C::utf8, 0x201D::utf8, 0x2022::utf8, 0x2013::utf8,
        0x2014::utf8, 0x02DC::utf8, 0x2122::utf8, 0x0161::utf8, 0x203A::utf8, 0x0153::utf8,
        0x017E::utf8, 0x0178::utf8, 0x00A0::utf8, 0x00A1::utf8, 0x00A2::utf8, 0x00A3::utf8,
        0x00A4::utf8, 0x00A5::utf8, 0x00A6::utf8, 0x00A7::utf8, 0x00A8::utf8, 0x00A9::utf8>>,
      <<0x00AA::utf8, 0x00AB::utf8, 0x00AC::utf8, 0x00AD::utf8, 0x00AE::utf8, 0x00AF::utf8,
        0x00B0::utf8, 0x00B1::utf8, 0x00B2::utf8, 0x00B3::utf8, 0x00B4::utf8, 0x00B5::utf8,
        0x00B6::utf8, 0x00B7::utf8, 0x00B8::utf8, 0x00B9::utf8, 0x00BA::utf8, 0x00BB::utf8,
        0x00BC::utf8, 0x00BD::utf8, 0x00BE::utf8, 0x00BF::utf8, 0x00C0::utf8, 0x00C1::utf8,
        0x00C2::utf8, 0x00C3::utf8, 0x00C4::utf8, 0x00C5::utf8, 0x00C6::utf8, 0x00C7::utf8,
        0x00C8::utf8, 0x00C9::utf8, 0x00CA::utf8, 0x00CB::utf8, 0x00CC::utf8, 0x00CD::utf8,
        0x00CE::utf8, 0x00CF::utf8, 0x00D0::utf8, 0x00D1::utf8, 0x00D2::utf8, 0x00D3::utf8,
        0x00D4::utf8, 0x00D5::utf8, 0x00D6::utf8, 0x00D7::utf8, 0x00D8::utf8, 0x00D9::utf8,
        0x00DA::utf8, 0x00DB::utf8, 0x00DC::utf8, 0x00DD::utf8, 0x00DE::utf8, 0x00DF::utf8,
        0x00E0::utf8, 0x00E1::utf8, 0x00E2::utf8, 0x00E3::utf8, 0x00E4::utf8, 0x00E5::utf8,
        0x00E6::utf8, 0x00E7::utf8, 0x00E8::utf8, 0x00E9::utf8, 0x00EA::utf8, 0x00EB::utf8,
        0x00EC::utf8, 0x00ED::utf8, 0x00EE::utf8, 0x00EF::utf8, 0x00F0::utf8, 0x00F1::utf8,
        0x00F2::utf8, 0x00F3::utf8, 0x00F4::utf8, 0x00F5::utf8, 0x00F6::utf8, 0x00F7::utf8,
        0x00F8::utf8, 0x00F9::utf8, 0x00FA::utf8, 0x00FB::utf8, 0x00FC::utf8, 0x00FD::utf8,
        0x00FE::utf8, 0x00FF::utf8>>
    ]

    Enum.reduce(strings, offset, fn string, {x, y} ->
      Pdf.text_at(pdf, {x, y}, string)
      {x, y - 10}
    end)

    pdf
  end

  test "exception is passed through" do
    Pdf.build([size: :a4, compress: false], fn pdf ->
      assert_raise RuntimeError,
                   "The supplied text did not fit within the supplied boundary",
                   fn ->
                     pdf
                     |> Pdf.set_font("Helvetica", 12)
                     |> Pdf.text_wrap!({10, 20}, {200, 10}, "Hello\nworld")
                   end
    end)
  end
end
