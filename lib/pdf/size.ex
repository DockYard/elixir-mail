defprotocol Pdf.Size do
  def size_of(object)
end

defimpl Pdf.Size, for: BitString do
  def size_of(string),
    do: byte_size(string)
end

defimpl Pdf.Size, for: Integer do
  def size_of(number),
    do: Pdf.Size.size_of(Integer.to_string(number))
end

defimpl Pdf.Size, for: DateTime do
  def size_of(_date),
    do: 24
end
