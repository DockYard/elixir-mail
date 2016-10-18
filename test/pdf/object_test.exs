defmodule Pdf.ObjectTest do
  use ExUnit.Case, async: true

  alias Pdf.Object

  test "new/1" do
    object = Object.new(1)
    assert object.size == 16

    object = Object.new(12)
    assert object.size == 17
  end

  test "set_value/2" do
    object =
      Object.new(1)
      |> Object.set_value("A string")
    assert %Object{value: "A string"} = object
  end

  test "to_iolist/1" do
    object =
      Object.new(1)
      |> Object.set_value("A string")

    iolist = Object.to_iolist(object)
    assert iolist == ["1", " ", "0", " obj\n", ["(", "A string", ")"], "\nendobj\n"]

    string = :erlang.iolist_to_binary(iolist)
    assert Object.size(object) == byte_size(string)
  end

  test "reference/1" do
    object = Object.new(13)

    assert Object.reference(object) == "13 0 R"
  end
end
