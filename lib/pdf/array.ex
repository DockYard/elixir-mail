defmodule Pdf.Array do
  defstruct values: []

  import Pdf.Size

  @array_start "[ "
  @array_start_length byte_size(@array_start)
  @array_end "]"
  @array_end_length byte_size(@array_end)
  @initial_length @array_start_length + @array_end_length

  def new(list), do: %__MODULE__{values: list}

  def size(array), do: calculate_size(array.values)

  def to_iolist(%Pdf.Array{values: values}) do
    Pdf.Export.to_iolist([
      @array_start,
      Enum.map(values, fn value -> [value, " "] end),
      @array_end
    ])
  end

  defp calculate_size([]), do: 0

  defp calculate_size([_ | _] = list) do
    @initial_length + Enum.reduce(list, length(list), fn value, acc -> acc + size_of(value) end)
  end

  defimpl Pdf.Size do
    def size_of(%Pdf.Array{} = array), do: Pdf.Array.size(array)
  end

  defimpl Pdf.Export do
    def to_iolist(array), do: Pdf.Array.to_iolist(array)
  end
end
