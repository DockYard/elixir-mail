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
         String.pad_leading(to_string(date.month), 2, "0"),
         String.pad_leading(to_string(date.day), 2, "0"),
         String.pad_leading(to_string(date.hour), 2, "0"),
         String.pad_leading(to_string(date.minute), 2, "0"),
         String.pad_leading(to_string(date.second), 2, "0"),
         "Z00'00)"]
end
