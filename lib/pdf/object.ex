defmodule Pdf.Object do
  defstruct number: nil, generation: "0", size: 0, value: nil

  @obj_start " obj\n"
  @obj_end "\nendobj\n"

  def new(number),
    do: %__MODULE__{number: to_string(number), size: 15 + String.length(to_string(number))}

  def set_value(object, value),
    do: %{object | value: value}

  def to_iolist(object) do
    [object.number, " ", object.generation, @obj_start, value_to_iolist(object.value), @obj_end]
  end

  def size(object),
    do: object.size + value_size(object.value)

  def reference(%__MODULE__{number: number, generation: generation}),
    do: "#{number} #{generation} R"

  defp value_to_iolist(string) when is_binary(string),
    do: ["(", string, ")"]

  defp value_size(string) when is_binary(string),
    do: 2 + byte_size(string)
end
