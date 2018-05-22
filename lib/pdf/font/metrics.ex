defmodule Pdf.Font.Metrics do
  @moduledoc false

  defstruct name: nil,
            full_name: nil,
            family: nil,
            weight: nil,
            italic_angle: nil,
            encoding: nil,
            first_char: nil,
            last_char: nil,
            ascender: nil,
            descender: nil,
            cap_height: nil,
            x_height: nil,
            widths: []

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

  def process_line(<<"C -1 ;", _reset::binary>>, metrics), do: metrics

  def process_line(
        <<"C ", number::binary-size(2), " ;", _rest::binary>> = line,
        %{first_char: nil} = metrics
      ) do
    process_line(line, %{metrics | first_char: String.to_integer(number)})
  end

  def process_line(
        <<"C ", number::binary-size(3), " ;", _rest::binary>> = line,
        %{first_char: nil} = metrics
      ) do
    process_line(line, %{metrics | first_char: String.to_integer(number)})
  end

  def process_line(
        <<"C ", _number::binary-size(2), " ; WX ", width::binary-size(2), " ; ", _rest::binary>>,
        %{widths: widths} = metrics
      ) do
    %{metrics | widths: [String.to_integer(width) | widths]}
  end

  def process_line(
        <<"C ", _number::binary-size(2), " ; WX ", width::binary-size(3), " ; ", _rest::binary>>,
        %{widths: widths} = metrics
      ) do
    %{metrics | widths: [String.to_integer(width) | widths]}
  end

  def process_line(
        <<"C ", _number::binary-size(2), " ; WX ", width::binary-size(4), " ; ", _rest::binary>>,
        %{widths: widths} = metrics
      ) do
    %{metrics | widths: [String.to_integer(width) | widths]}
  end

  def process_line(
        <<"C ", _number::binary-size(3), " ; WX ", width::binary-size(2), " ; ", _rest::binary>>,
        %{widths: widths} = metrics
      ) do
    %{metrics | widths: [String.to_integer(width) | widths]}
  end

  def process_line(
        <<"C ", _number::binary-size(3), " ; WX ", width::binary-size(3), " ; ", _rest::binary>>,
        %{widths: widths} = metrics
      ) do
    %{metrics | widths: [String.to_integer(width) | widths]}
  end

  def process_line(
        <<"C ", _number::binary-size(3), " ; WX ", width::binary-size(4), " ; ", _rest::binary>>,
        %{widths: widths} = metrics
      ) do
    %{metrics | widths: [String.to_integer(width) | widths]}
  end

  def process_line(_line, metrics), do: metrics
end
