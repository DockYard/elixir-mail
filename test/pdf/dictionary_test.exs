defmodule Pdf.DictionaryTest do
  use ExUnit.Case, async: true

  alias Pdf.Dictionary

  test "put/3 with a string value" do
    dictionary = Dictionary.put(%Dictionary{}, "Name", "Value")
    assert dictionary == %Dictionary{size: 19, entries: %{{:name, "Name"} => {:string, "Value"}}}
  end

  test "put/3 with a dictionary value" do
    dictionary = Dictionary.put(Dictionary.new, "Name", "Value")
    dictionary2 = Dictionary.put(Dictionary.new, "Name", dictionary)
    assert dictionary2 == %Dictionary{size: 12, entries: %{{:name, "Name"} => %Dictionary{size: 19, entries: %{{:name, "Name"} => {:string, "Value"}}}}}
  end

  test "size/1" do
    dictionary = Dictionary.put(Dictionary.new, "Name", "Value")
    dictionary2 = Dictionary.put(Dictionary.new, "Name", dictionary)
    assert Dictionary.size(dictionary2) == 31
  end

  test "to_iolist/1" do
    dictionary =
      Dictionary.new
      |> Dictionary.put("Name", "Value")
      |> Dictionary.put("Key", "Value2")
    iolist = Pdf.Export.to_iolist(dictionary)
    assert iolist == ["<<\n", [[["/", "Key"], " ", ["(", "Value2", ")"], "\n"], [["/", "Name"], " ", ["(", "Value", ")"], "\n"]], ">>"]
    string = :erlang.iolist_to_binary(iolist)
    assert dictionary.size == String.length(string)
  end

  test "to_iolist/1 with an embedded dictionary" do
    dictionary =
      Dictionary.new
      |> Dictionary.put("Name", "Value")
      |> Dictionary.put("Key", Dictionary.put(Dictionary.new, "Key", "Value2"))
    iolist = Pdf.Export.to_iolist(dictionary)
    assert iolist == ["<<\n", [[["/", "Key"], " ", ["<<\n", [[["/", "Key"], " ", ["(", "Value2", ")"], "\n"]], ">>"], "\n"], [["/", "Name"], " ", ["(", "Value", ")"], "\n"]], ">>"]
    string = :erlang.iolist_to_binary(iolist)
    assert Dictionary.size(dictionary) == String.length(string)
  end
end
