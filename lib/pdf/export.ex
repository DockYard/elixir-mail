defprotocol Pdf.Export do
  def to_iolist(object)
end

defimpl Pdf.Export, for: List do
  def to_iolist([]), do: []
  def to_iolist(list), do: Enum.map(list, &Pdf.Export.to_iolist/1)
end

defimpl Pdf.Export, for: BitString do
  def to_iolist(string), do: string
end

defimpl Pdf.Export, for: Integer do
  def to_iolist(number), do: Pdf.Export.to_iolist(Integer.to_string(number))
end

defimpl Pdf.Export, for: Float do
  def to_iolist(number),
    do: Pdf.Export.to_iolist(:erlang.float_to_binary(number, [:compact, decimals: 4]))
end

defimpl Pdf.Export, for: Date do
  def to_iolist(date) do
    [
      "(D:",
      to_string(date.year),
      pad_datepart(date.month),
      pad_datepart(date.day),
      ")"
    ]
  end

  defp pad_datepart(part), do: part |> to_string |> String.pad_leading(2, "0")
end

defimpl Pdf.Export, for: DateTime do
  def to_iolist(date) do
    [
      "(D:",
      to_string(date.year),
      pad_datepart(date.month),
      pad_datepart(date.day),
      pad_datepart(date.hour),
      pad_datepart(date.minute),
      pad_datepart(date.second),
      timezone_info(date),
      ")"
    ]
  end

  defp pad_datepart(part), do: part |> to_string |> String.pad_leading(2, "0")

  defp timezone_info(%{utc_offset: 0}), do: "Z"
  defp timezone_info(%{utc_offset: offset}) when offset > 0, do: ["+", format_offset(offset)]
  defp timezone_info(%{utc_offset: offset}) when offset < 0, do: ["-", format_offset(abs(offset))]

  defp format_offset(offset) do
    minutes = round(offset / 60)
    hours = round(minutes / 60)
    [pad_datepart(hours), "'", pad_datepart(rem(minutes, 60))]
  end
end

defimpl Pdf.Export, for: Tuple do
  def to_iolist({:string, string}), do: ["(", string, ")"]

  def to_iolist({:name, name}), do: ["/", name]

  def to_iolist({:object, number, generation}),
    do: [Integer.to_string(number), " ", Integer.to_string(generation), " R"]

  def to_iolist({:command, []}), do: []

  def to_iolist({:command, [head | tail]}),
    do: [Pdf.Export.to_iolist(head), Enum.map(tail, &[" ", Pdf.Export.to_iolist(&1)])]

  def to_iolist({:command, command}), do: command
end
