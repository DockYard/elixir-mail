defmodule Pdf.Font.Metrics do
  @moduledoc false

  defmodule Glyph do
    defstruct name: nil,
              char_code: 0x00,
              width: 0,
              bbox: []
  end

  defstruct name: nil,
            full_name: nil,
            family: nil,
            weight: nil,
            italic_angle: nil,
            encoding: nil,
            first_char: 0,
            last_char: 255,
            ascender: nil,
            descender: nil,
            cap_height: nil,
            x_height: nil,
            fixed_pitch: false,
            bbox: nil,
            widths: [],
            glyphs: %{}

  def widths(metrics, encoding \\ Pdf.Encoding.WinAnsi) do
    Enum.map(encoding.characters(), fn char_code ->
      case metrics.glyphs[char_code] do
        nil -> 0
        %{width: width} -> width
      end
    end)
  end

  defp print_char(width, char_code) do
    try do
      IO.inspect(width, label: <<char_code::utf8>>)
    rescue
      ArgumentError ->
        nil
    end
  end

  def process_line(<<"FontName ", data::binary>>, metrics), do: %{metrics | name: data}
  def process_line(<<"FullName ", data::binary>>, metrics), do: %{metrics | full_name: data}
  def process_line(<<"FamilyName ", data::binary>>, metrics), do: %{metrics | family: data}

  def process_line(<<"Weight ", data::binary>>, metrics),
    do: %{metrics | weight: String.to_atom(String.downcase(data))}

  def process_line(<<"ItalicAngle ", data::binary>>, metrics),
    do: %{metrics | italic_angle: Float.parse(data)}

  def process_line(<<"EncodingScheme ", data::binary>>, metrics), do: %{metrics | encoding: data}

  def process_line(<<"CapHeight ", data::binary>>, metrics),
    do: %{metrics | cap_height: String.to_integer(data)}

  def process_line(<<"XHeight ", data::binary>>, metrics),
    do: %{metrics | x_height: String.to_integer(data)}

  def process_line(<<"Ascender ", data::binary>>, metrics),
    do: %{metrics | ascender: String.to_integer(data)}

  def process_line(<<"Descender ", data::binary>>, metrics),
    do: %{metrics | descender: String.to_integer(data)}

  def process_line("IsFixedPitch true", metrics),
    do: %{metrics | fixed_pitch: true}

  def process_line(<<"FontBBox ", data::binary>>, metrics) do
    bbox =
      data
      |> String.split(" ", trim: true)
      |> Enum.map(fn f -> Float.parse(f) |> elem(0) end)
      |> Enum.map(fn f -> :erlang.float_to_binary(f, decimals: 1) end)

    %{metrics | bbox: bbox}
  end

  def process_line(<<"C ", _rest::binary>> = line, %{glyphs: glyphs} = metrics) do
    glyph = parse_glyph(line)
    %{metrics | glyphs: Map.put(glyphs, glyph.char_code, glyph)}
  end

  # def process_line(
  #       <<"C ", number::binary-size(2), " ;", _rest::binary>> = line,
  #       %{first_char: nil} = metrics
  #     ) do
  #   process_line(line, %{metrics | first_char: String.to_integer(number)})
  # end

  # def process_line(
  #       <<"C ", number::binary-size(3), " ;", _rest::binary>> = line,
  #       %{first_char: nil} = metrics
  #     ) do
  #   process_line(line, %{metrics | first_char: String.to_integer(number)})
  # end

  # def process_line(
  #       <<"C ", _number::binary-size(1), " ; WX ", width::binary-size(2), " ; ", _rest::binary>>,
  #       %{widths: widths} = metrics
  #     ) do
  #   %{metrics | widths: [String.to_integer(width) | widths]}
  # end

  # def process_line(
  #       <<"C ", _number::binary-size(1), " ; WX ", width::binary-size(3), " ; ", _rest::binary>>,
  #       %{widths: widths} = metrics
  #     ) do
  #   %{metrics | widths: [String.to_integer(width) | widths]}
  # end

  # def process_line(
  #       <<"C ", _number::binary-size(1), " ; WX ", width::binary-size(4), " ; ", _rest::binary>>,
  #       %{widths: widths} = metrics
  #     ) do
  #   %{metrics | widths: [String.to_integer(width) | widths]}
  # end

  # def process_line(
  #       <<"C ", _number::binary-size(2), " ; WX ", width::binary-size(2), " ; ", _rest::binary>>,
  #       %{widths: widths} = metrics
  #     ) do
  #   %{metrics | widths: [String.to_integer(width) | widths]}
  # end

  # def process_line(
  #       <<"C ", _number::binary-size(2), " ; WX ", width::binary-size(3), " ; ", _rest::binary>>,
  #       %{widths: widths} = metrics
  #     ) do
  #   %{metrics | widths: [String.to_integer(width) | widths]}
  # end

  # def process_line(
  #       <<"C ", _number::binary-size(2), " ; WX ", width::binary-size(4), " ; ", _rest::binary>>,
  #       %{widths: widths} = metrics
  #     ) do
  #   %{metrics | widths: [String.to_integer(width) | widths]}
  # end

  # def process_line(
  #       <<"C ", _number::binary-size(3), " ; WX ", width::binary-size(2), " ; ", _rest::binary>>,
  #       %{widths: widths} = metrics
  #     ) do
  #   %{metrics | widths: [String.to_integer(width) | widths]}
  # end

  # def process_line(
  #       <<"C ", _number::binary-size(3), " ; WX ", width::binary-size(3), " ; ", _rest::binary>>,
  #       %{widths: widths} = metrics
  #     ) do
  #   %{metrics | widths: [String.to_integer(width) | widths]}
  # end

  # def process_line(
  #       <<"C ", _number::binary-size(3), " ; WX ", width::binary-size(4), " ; ", _rest::binary>>,
  #       %{widths: widths} = metrics
  #     ) do
  #   %{metrics | widths: [String.to_integer(width) | widths]}
  # end

  def process_line(_line, metrics), do: metrics

  defp parse_glyph(line) do
    line
    |> String.trim()
    |> String.split(~r/\s*;\s*/)
    |> parse_glyph(%Glyph{})
  end

  defp parse_glyph([], glyph), do: glyph

  defp parse_glyph(["" | tail], glyph),
    do: parse_glyph(tail, glyph)

  defp parse_glyph([<<"C ", _rest::binary>> | tail], glyph),
    do: parse_glyph(tail, glyph)

  defp parse_glyph([<<"N ", name::binary>> | tail], glyph) do
    char_code = Pdf.Encoding.WinAnsi.from_name(name)
    parse_glyph(tail, %{glyph | name: name, char_code: char_code})
  end

  defp parse_glyph([<<"WX ", width::binary>> | tail], glyph) do
    glyph =
      case Integer.parse(width) do
        {width, _} -> %{glyph | width: width}
        :error -> glyph
      end

    parse_glyph(tail, glyph)
  end

  defp parse_glyph([<<"B ", data::binary>> | tail], glyph) do
    bbox =
      data
      |> String.split(" ", trim: true)
      |> Enum.map(fn f -> Float.parse(f) |> elem(0) end)
      |> Enum.map(fn f -> :erlang.float_to_binary(f, decimals: 1) end)

    %{glyph | bbox: bbox}

    parse_glyph(tail, glyph)
  end

  defp parse_glyph([_ | tail], glyph),
    do: parse_glyph(tail, glyph)
end
