defmodule Pdf.RefTable do
  alias Pdf.Object

  def to_iolist(objects, offset \\ 0) do
    {objects_iolist, offset} = objects_to_iolist(objects, offset)
    {["xref\n", "0", " ", to_string(length(objects) + 1), "\n", first_reference, objects_iolist], offset}
  end

  defp first_reference,
    do: "0000000000 65535 f\n"

  defp objects_to_iolist(list, offset, acc \\ [])
  defp objects_to_iolist([], offset, acc), do: {Enum.reverse(acc), offset}
  defp objects_to_iolist([object | tail], offset, acc) do
    iolist = object_to_ref(object, offset)
    offset = offset + Object.size(object)
    objects_to_iolist(tail, offset, [iolist | acc])
  end

  defp object_to_ref(object, offset) do
    [String.pad_leading(to_string(offset), 10, "0"), " ", String.pad_leading(object.generation, 5, "0"), " n\n"]
  end
end
