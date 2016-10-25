defprotocol Pdf.Export do
  def to_iolist(object)
end

defimpl Pdf.Export, for: List do
  def to_iolist([]), do: []
  def to_iolist(list),
    do: Enum.map(list, &Pdf.Export.to_iolist/1)
end

defimpl Pdf.Export, for: BitString do
  def to_iolist(string),
    do: string
end

defimpl Pdf.Export, for: Integer do
  def to_iolist(number),
    do: Pdf.Export.to_iolist(Integer.to_string(number))
end

defimpl Pdf.Export, for: DateTime do
  def to_iolist(date),
    do: ["(D:", to_string(date.year),
         pad_datepart(date.month),
         pad_datepart(date.day),
         pad_datepart(date.hour),
         pad_datepart(date.minute),
         pad_datepart(date.second),
         "Z00'00)"]

  defp pad_datepart(part),
    do: part |> to_string |> String.pad_leading(2, "0")
end

defimpl Pdf.Export, for: Tuple do
  def to_iolist({:name, name}),
    do: ["/", name]

  def to_iolist({:string, string}),
    do: ["(", string, ")"]

  def to_iolist({:object, number, generation}),
    do: [Integer.to_string(number), " ", Integer.to_string(generation), " R"]
end
