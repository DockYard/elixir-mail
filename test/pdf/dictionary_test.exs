defmodule Pdf.DictionaryTest do
  use ExUnit.Case, async: true

  alias Pdf.Dictionary

  test "add/3 with a string value" do
    dictionary = Dictionary.add(%Dictionary{}, "Name", "Value")
    assert dictionary == %Dictionary{size: 17, entries: %{"Name" => "Value"}}
  end

  test "add/3 with a dictionary value" do
    dictionary = Dictionary.add(%Dictionary{}, "Name", "Value")
    dictionary2 = Dictionary.add(%Dictionary{}, "Name", dictionary)
    assert dictionary2 == %Dictionary{size: 12, entries: %{"Name" => %Dictionary{size: 17, entries: %{"Name" => "Value"}}}}
  end

  test "size/1" do
    dictionary = Dictionary.add(%Dictionary{}, "Name", "Value")
    dictionary2 = Dictionary.add(%Dictionary{}, "Name", dictionary)
    assert Dictionary.size(dictionary2) == 29
  end

  test "to_iolist/1" do
    dictionary =
      %Dictionary{}
      |> Dictionary.add("Name", "Value")
      |> Dictionary.add("Key", "Value2")
    iolist = Dictionary.to_iolist(dictionary)
    assert iolist == ["<< ", [["/", "Key", " ", "Value2", "\n"], ["/", "Name", " ", "Value", "\n"]], ">>"]
    string = :erlang.iolist_to_binary(iolist)
    assert dictionary.size == String.length(string)
  end

  test "to_iolist/1 with an embedded dictionary" do
    dictionary =
      %Dictionary{}
      |> Dictionary.add("Name", "Value")
      |> Dictionary.add("Key", Dictionary.add(%Dictionary{}, "Key", "Value2"))
    iolist = Dictionary.to_iolist(dictionary)
    assert iolist == ["<< ", [["/", "Key", " ", ["<< ", [["/", "Key", " ", "Value2", "\n"]], ">>"], "\n"], ["/", "Name", " ", "Value", "\n"]], ">>"]
    string = :erlang.iolist_to_binary(iolist)
    assert Dictionary.size(dictionary) == String.length(string)
  end
end
