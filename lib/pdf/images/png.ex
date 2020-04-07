defmodule Pdf.Images.PNG do
  import Pdf.Utils

  alias Pdf.{Image, Dictionary, Stream, ObjectCollection}

  defstruct bit_depth: nil,
            height: nil,
            width: nil,
            color_type: nil,
            compression_method: nil,
            filter_method: nil,
            interlace_method: nil,
            image_data: <<>>,
            palette: <<>>,
            alpha: <<>>

  @doc ~S"""
  Decodes an image and returns the bit depth, height, width and colour type

  Examples:

      > Pdf.Image.PNG.decode("path/to/image.png")
      {:ok, {8, 75, 100, 3}) # 8 bits, height: 75px, width: 100px, color type: 3 (indexed colour)
  """
  def decode(image_data) do
    parse(image_data, %__MODULE__{})
  end

  defp parse(image_data), do: parse(image_data, %__MODULE__{})

  defp parse(
         <<137, 80, 78, 71, 13, 10, 26, 10, rest::binary>>,
         data
       ) do
    parse(rest, data)
  end

  defp parse("", data), do: data

  defp parse(
         <<length::unsigned-32, type::binary-size(4), payload::binary-size(length),
           _crc::unsigned-32, rest::binary>>,
         data
       ) do
    data = parse_chunk(type, payload, data)
    parse(rest, data)
  end

  defp parse_chunk(
         "IHDR",
         <<width::unsigned-32, height::unsigned-32, bit_depth::unsigned-8, color_type::unsigned-8,
           compression_method::unsigned-8, filter_method::unsigned-8,
           interlace_method::unsigned-8, _rest::binary>>,
         data
       ) do
    %{
      data
      | width: width,
        height: height,
        bit_depth: bit_depth,
        color_type: color_type,
        compression_method: compression_method,
        filter_method: filter_method,
        interlace_method: interlace_method
    }
  end

  defp parse_chunk("IDAT", payload, %{compression_method: 0} = data) do
    %{data | image_data: <<data.image_data::binary, payload::binary>>}
  end

  defp parse_chunk("PLTE", payload, %{compression_method: 0} = data) do
    %{data | palette: <<data.palette::binary, payload::binary>>}
  end

  defp parse_chunk("IEND", _payload, %{color_type: color_type, image_data: image_data} = data)
       when color_type in [4, 6] do
    {image_data, alpha} = extract_alpha_channel(data, image_data)
    %{data | image_data: image_data, alpha: alpha}
  end

  defp parse_chunk("IEND", _payload, data), do: data

  # defp parse_chunk("cHRM", _payload, data), do: data
  # defp parse_chunk("gAMA", _payload, data), do: data
  # defp parse_chunk("bKGD", _payload, data), do: data
  # defp parse_chunk("tIME", _payload, data), do: data
  # defp parse_chunk("tEXt", _payload, data), do: data
  # defp parse_chunk("zTXt", _payload, data), do: data
  # defp parse_chunk("iTXt", _payload, data), do: data
  # defp parse_chunk("iCCP", _payload, data), do: data
  # defp parse_chunk("sRGB", _payload, data), do: data
  # defp parse_chunk("pHYs", _payload, data), do: data

  defp parse_chunk(_, _payload, data), do: data

  defp extract_alpha_channel(data, image_data) do
    %{color_type: color_type, bit_depth: bit_depth, width: width} = data
    image_data = inflate(image_data)
    colors = get_colors(color_type)
    alpha_bytes = round(bit_depth / 8)
    color_bytes = round(colors * bit_depth / 8)
    scanline_length = round((color_bytes + alpha_bytes) * width + 1)
    scan_lines = extract_scan_lines(image_data, scanline_length - 1)
    {color_data, alpha_data} = breakout_lines({color_bytes, alpha_bytes}, scan_lines)
    {deflate(color_data), alpha_data}
  end

  defp extract_scan_lines(<<>>, _line_length), do: []

  defp extract_scan_lines(image_data, line_length) do
    <<filter::unsigned-8, line::binary-size(line_length), rest::binary>> = image_data
    [{filter, line} | extract_scan_lines(rest, line_length)]
  end

  defp breakout_lines(sizes, scan_lines, color_data \\ <<>>, alpha_data \\ <<>>)

  defp breakout_lines(_sizes, [], color_data, alpha_data), do: {color_data, alpha_data}

  defp breakout_lines(
         {color_bytes, alpha_bytes},
         [{filter, line} | tail],
         color_data,
         alpha_data
       ) do
    {color, alpha} = breakout_line({color_bytes, alpha_bytes}, line)

    breakout_lines(
      {color_bytes, alpha_bytes},
      tail,
      <<color_data::binary, filter::unsigned-8, color::binary>>,
      <<alpha_data::binary, filter::unsigned-8, alpha::binary>>
    )
  end

  defp breakout_line(sizes, line, color_data \\ <<>>, alpha_data \\ <<>>)

  defp breakout_line(_sizes, "", color_data, alpha_data), do: {color_data, alpha_data}

  defp breakout_line({color_bytes, alpha_bytes}, line, color_data, alpha_data) do
    <<color::binary-size(color_bytes), alpha::binary-size(alpha_bytes), rest::binary>> = line

    breakout_line(
      {color_bytes, alpha_bytes},
      rest,
      <<color_data::binary, color::binary-size(color_bytes)>>,
      <<alpha_data::binary, alpha::binary-size(alpha_bytes)>>
    )
  end

  def prepare_image(image_data, objects) do
    %__MODULE__{bit_depth: bits, height: height, width: width} = image = parse(image_data)

    extra = prepare_extra(image, objects)

    build_dictionary(
      %Image{
        bits: bits,
        height: height,
        width: width,
        data: image.image_data,
        size: byte_size(image.image_data)
      },
      extra
    )
  end

  # Grayscale
  defp prepare_extra(%{color_type: 0} = image, _objects) do
    %{
      "Filter" => n("FlateDecode"),
      "DecodeParms" =>
        Dictionary.new(%{
          "Predictor" => 15,
          "Colors" => get_colors(image.color_type),
          "BitsPerComponent" => image.bit_depth,
          "Columns" => image.width
        }),
      "ColorSpace" => n(get_colorspace(image.color_type)),
      "BitsPerComponent" => image.bit_depth
    }
  end

  # Truecolour
  defp prepare_extra(%{color_type: 2} = image, _objects) do
    %{
      "Filter" => n("FlateDecode"),
      "DecodeParms" =>
        Dictionary.new(%{
          "Predictor" => 15,
          "Colors" => get_colors(image.color_type),
          "BitsPerComponent" => image.bit_depth,
          "Columns" => image.width
        }),
      "ColorSpace" => n(get_colorspace(image.color_type)),
      "BitsPerComponent" => image.bit_depth
    }
  end

  # Indexed-colour
  defp prepare_extra(%{color_type: 3} = image, objects) do
    stream = Stream.set(Stream.new(compress: false), image.palette)
    {:object, number, _} = object_key = ObjectCollection.create_object(objects, stream)
    _object = Pdf.Object.new(number, ObjectCollection.get_object(objects, object_key))

    %{
      "Filter" => n("FlateDecode"),
      "DecodeParms" =>
        Dictionary.new(%{
          "Predictor" => 15,
          "Colors" => get_colors(image.color_type),
          "BitsPerComponent" => image.bit_depth,
          "Columns" => image.width
        }),
      "ColorSpace" =>
        a([
          n("Indexed"),
          n("DeviceRGB"),
          round(byte_size(image.palette) / 3 - 1),
          object_key
        ]),
      "BitsPerComponent" => image.bit_depth
    }
  end

  # Greyscale with alpha (4)
  # Truecolour with alpha (6)
  defp prepare_extra(%{color_type: color_type} = image, objects) when color_type in [4, 6] do
    stream =
      Stream.set(
        Stream.new(
          compress: true,
          dictionary: %{
            "Type" => n("XObject"),
            "Subtype" => n("Image"),
            "Height" => image.height,
            "Width" => image.width,
            "BitsPerComponent" => image.bit_depth,
            "ColorSpace" => n("DeviceGray"),
            "Decode" => a([0, 1]),
            "DecodeParms" =>
              Dictionary.new(%{
                "Predictor" => 15,
                "Colors" => 1,
                "BitsPerComponent" => image.bit_depth,
                "Columns" => image.width
              })
          }
        ),
        image.alpha
      )

    {:object, number, _} = object_key = ObjectCollection.create_object(objects, stream)
    _object = Pdf.Object.new(number, ObjectCollection.get_object(objects, object_key))

    %{
      "Filter" => n("FlateDecode"),
      "DecodeParms" =>
        Dictionary.new(%{
          "Predictor" => 15,
          "Colors" => get_colors(color_type),
          "BitsPerComponent" => image.bit_depth,
          "Columns" => image.width
        }),
      "ColorSpace" => n(get_colorspace(color_type)),
      "BitsPerComponent" => image.bit_depth,
      "SMask" => object_key
    }
  end

  defp get_colorspace(0), do: "DeviceGray"
  defp get_colorspace(2), do: "DeviceRGB"
  defp get_colorspace(3), do: "DeviceGray"
  defp get_colorspace(4), do: "DeviceGray"
  defp get_colorspace(6), do: "DeviceRGB"

  defp get_colors(0), do: 1
  defp get_colors(2), do: 3
  defp get_colors(3), do: 1
  defp get_colors(4), do: 1
  defp get_colors(6), do: 3

  def build_dictionary(%Image{} = image, extra) do
    %{width: width, height: height, size: size} = image

    image_dic =
      Dictionary.new(
        Map.merge(
          %{
            "Type" => n("XObject"),
            "Subtype" => n("Image"),
            "Width" => width,
            "Height" => height,
            "Length" => size
          },
          extra
        )
      )

    %{image | dictionary: image_dic}
  end

  defp inflate(compressed) do
    z = :zlib.open()
    :ok = :zlib.inflateInit(z)
    uncompressed = :zlib.inflate(z, compressed)
    :zlib.inflateEnd(z)
    :erlang.list_to_binary(uncompressed)
  end

  defp deflate(data) do
    z = :zlib.open()
    :ok = :zlib.deflateInit(z)
    compressed = :zlib.deflate(z, data, :finish)
    :zlib.deflateEnd(z)
    :erlang.list_to_binary(compressed)
  end
end
