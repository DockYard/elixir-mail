defmodule Pdf.Images.JPEG do
  import Pdf.Utils

  alias Pdf.{Array, Dictionary, Image}

  defstruct bit_depth: nil,
            height: nil,
            width: nil,
            color_type: nil,
            image_data: <<>>

  @doc ~S"""
  Decodes an image and returns the bit depth, height, width and colour color_type

  Examples:

      > Pdf.Image.JPEG.decode("path/to/image.jpg")
      %Pdf.Image.JPEG{bit_depth: 8, height: 75, width: 100, color_type: 3}
  """
  def decode(image_data) do
    parse_jpeg(image_data)
  end

  defp parse_jpeg(<<255, 216, rest::binary>>), do: parse_jpeg(rest)

  [192, 193, 194, 195, 197, 198, 199, 201, 202, 203, 205, 206, 207]
  |> Enum.each(fn code ->
    defp parse_jpeg(<<255, unquote(code), _length::unsigned-integer-size(16), rest::binary>>),
      do: parse_image_data(rest)
  end)

  defp parse_jpeg(<<255, _code, length::unsigned-integer-size(16), rest::binary>>) do
    {:ok, data} = chomp(rest, length - 2)
    parse_jpeg(data)
  end

  def parse_image_data(
        <<bits, height::unsigned-integer-size(16), width::unsigned-integer-size(16), color_type,
          _rest::binary>>
      ) do
    %__MODULE__{bit_depth: bits, height: height, width: width, color_type: color_type}
  end

  def parse_image_data(_, _), do: {:error, :parse_error}

  defp chomp(data, length) do
    data = :erlang.binary_part(data, {length, byte_size(data) - length})
    {:ok, data}
  end

  def prepare_image(image_data) do
    %__MODULE__{bit_depth: bit_depth, height: height, width: width, color_type: color_type} =
      decode(image_data)

    build_dictionary(%Image{
      bits: bit_depth,
      height: height,
      width: width,
      color_type: color_type,
      data: image_data,
      size: byte_size(image_data)
    })
  end

  def build_dictionary(%Image{} = image) do
    %{bits: bit_depth, width: width, height: height, color_type: color_type, size: size} = image

    image_dic =
      Dictionary.new(%{
        "Type" => n("XObject"),
        "Subtype" => n("Image"),
        "ColorSpace" => get_colorspace(color_type),
        "BitsPerComponent" => bit_depth,
        "Width" => width,
        "Height" => height,
        "Length" => size,
        "Filter" => Array.new([n("DCTDecode")])
      })

    image_dic =
      if color_type == 4 do
        # Invert colours, See :4.8.4 of the spec
        Dictionary.put(image_dic, "Decode", Array.new([1, 0, 1, 0, 1, 0, 1, 0]))
      else
        image_dic
      end

    %{image | dictionary: image_dic}
  end

  defp get_colorspace(0), do: n("DeviceGray")
  defp get_colorspace(1), do: n("DeviceGray")
  defp get_colorspace(2), do: n("DeviceGray")
  defp get_colorspace(3), do: n("DeviceRGB")
  defp get_colorspace(4), do: n("DeviceCMYK")
  defp get_colorspace(_), do: raise("Unsupported number of JPG color_type")
end
