defmodule Pdf.Object do
  defstruct number: nil, generation: "0", size: 0, value: nil

  import Pdf.Size

  @obj_start " obj\n"
  @obj_end "\nendobj\n"
  @obj_start_size byte_size(@obj_start)
  @obj_end_size byte_size(@obj_end)
  @generation_size 1
  @initial_size @obj_start_size + @obj_end_size + @generation_size + 1 # space between object number and generation number

  def new(number),
    do: %__MODULE__{number: to_string(number), size: @initial_size + String.length(to_string(number))}

  def new(number, value),
    do: number |> new |> set_value(value)

  def set_value(object, value),
    do: %{object | value: value}

  def size(object),
    do: object.size + value_size(object.value)

  def to_iolist(object),
    do: Pdf.Export.to_iolist([object.number, " ", object.generation, @obj_start, Pdf.Object.value_to_iolist(object.value), @obj_end])

  def reference(%__MODULE__{number: number, generation: generation}),
    do: "#{number} #{generation} R"

  def value_to_iolist(string) when is_binary(string),
    do: ["(", string, ")"]
  def value_to_iolist(value),
    do: Pdf.Export.to_iolist(value)

  defp value_size(string) when is_binary(string),
    do: 2 + size_of(string)
  defp value_size(value),
    do: size_of(value)

  defimpl Pdf.Size do
    def size_of(%Pdf.Object{} = object),
      do: Pdf.Object.size(object)
  end

  defimpl Pdf.Export do
    def to_iolist(object),
      do: Pdf.Object.to_iolist(object)
  end
end
