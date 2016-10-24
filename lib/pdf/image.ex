defmodule Pdf.Image do
  defstruct bits: nil, width: nil, height: nil, channels: nil, size: nil, path: nil, dictionary: nil

  import Pdf.Size
  alias Pdf.{Array,Dictionary}

  @stream_start "\nstream\n"
  @stream_end "endstream"

  def new(image_path) do
    {:ok, {bits, height, width, channels}} = Pdf.Images.JPEG.decode(image_path)
    build_dictionary(%__MODULE__{
      bits: bits,
      height: height,
      width: width,
      channels: channels,
      path: image_path,
      size: get_file_size(image_path)
    })
  end

  def build_dictionary(%__MODULE__{bits: bits, width: width, height: height, channels: channels, path: path, size: size} = image) do
    image_dic = Dictionary.new(%{
      "Type" => "/XObject",
      "Subtype" => "/Image",
      "ColorSpace" => get_colorspace(channels),
      "BitsPerComponent" => bits,
      "Width" => width,
      "Height" => height,
      "Length" => size,
      "Filter" => Array.new(["/DCTDecode"])
    })
    image_dic = if channels == 4 do
      Dictionary.put(image_dic, "Decode", Array.new([1, 0, 1, 0, 1, 0, 1, 0])) # Invert colours, See :4.8.4 of the spec
    else
      image_dic
    end
    %{image | dictionary: image_dic}
  end

  defp get_colorspace(1), do: "/DeviceGray"
  defp get_colorspace(3), do: "/DeviceRGB"
  defp get_colorspace(4), do: "/DeviceCMYK"
  defp get_colorspace(_), do: raise "Unsupported number of JPG channels"

  defp get_file_size(path) do
    info = File.stat!(path)
    info.size
  end

  def size(%__MODULE__{size: size, dictionary: dictionary}) do
    size_of(dictionary) + size
  end

  def to_iolist(%__MODULE__{path: path, dictionary: dictionary}) do
    Pdf.Export.to_iolist([
      dictionary,
      @stream_start,
      File.read!(path),
      @stream_end
    ])
  end

  defimpl Pdf.Size do
    def size_of(%Pdf.Image{} = image),
      do: Pdf.Image.size(image)
  end

  defimpl Pdf.Export do
    def to_iolist(%Pdf.Image{} = image),
      do: Pdf.Image.to_iolist(image)
  end
end
