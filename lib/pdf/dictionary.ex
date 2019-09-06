defmodule Pdf.Dictionary do
  import Pdf.Size
  import Pdf.Utils

  @dict_start "<<\n"
  @dict_start_length byte_size(@dict_start)
  @dict_end ">>"
  @dict_end_length byte_size(@dict_end)
  @initial_length @dict_start_length + @dict_end_length
  @value_separator " "
  @value_separator_length byte_size(@value_separator)
  @entry_separator "\n"
  @entry_separator_length byte_size(@entry_separator)

  defstruct size: @initial_length, entries: %{}

  def new, do: %__MODULE__{size: @initial_length}

  def new(map) do
    map
    |> Enum.reduce(new(), fn {key, value}, dictionary ->
      put(dictionary, key, value)
    end)
  end

  def put(dictionary, key, value) when is_binary(value), do: put(dictionary, key, s(value))

  def put(dictionary, key, value) do
    key = n(key)

    case Map.fetch(dictionary.entries, key) do
      :error ->
        entries = Map.put(dictionary.entries, key, value)
        size = increment_internal_size(dictionary, key, value)
        %{dictionary | entries: entries, size: size}

      {:ok, ^value} ->
        dictionary

      {:ok, old_value} ->
        entries = Map.put(dictionary.entries, key, value)
        size = decrement_internal_size(dictionary, key, old_value)
        size = increment_internal_size(%{dictionary | size: size}, key, value)

        %{dictionary | entries: entries, size: size}
    end
  end

  defp increment_internal_size(%__MODULE__{size: size}, key, %{size: _size}),
    do: size + size_of(key) + @value_separator_length + @entry_separator_length

  defp increment_internal_size(dictionary, key, value),
    do: increment_internal_size(dictionary, key, %{size: 0}) + size_of(value)

  defp decrement_internal_size(%__MODULE__{size: size}, key, %{size: _size}),
    do: size - size_of(key) - @value_separator_length - @entry_separator_length

  defp decrement_internal_size(dictionary, key, value),
    do: decrement_internal_size(dictionary, key, %{size: 0}) - size_of(value)

  def size(dict) do
    dict
    |> to_iolist()
    |> :binary.list_to_bin()
    |> byte_size()
  end

  def to_iolist(dictionary) do
    [@dict_start, entries_to_iolist(dictionary.entries), @dict_end]
  end

  defp entries_to_iolist(%{} = entries), do: entries_to_iolist(Enum.to_list(entries))
  defp entries_to_iolist([]), do: []
  defp entries_to_iolist([entry | tail]), do: [entry_to_iolist(entry) | entries_to_iolist(tail)]

  defp entry_to_iolist({key, value}),
    do: Pdf.Export.to_iolist([key, @value_separator, value, @entry_separator])

  defimpl Pdf.Size do
    def size_of(%Pdf.Dictionary{} = dictionary), do: Pdf.Dictionary.size(dictionary)
  end

  defimpl Pdf.Export do
    def to_iolist(dictionary), do: Pdf.Dictionary.to_iolist(dictionary)
  end

  def to_map(%__MODULE__{entries: entries}) do
    entries
    |> Enum.map(fn {{:name, name}, value} ->
      {name, to_value(value)}
    end)
    |> Map.new()
  end

  defp to_value({:name, name}), do: name
  defp to_value({:string, string}), do: string
  defp to_value(other), do: other
end
