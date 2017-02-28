defmodule Mail.ProplistTest do
  use ExUnit.Case, async: true
  doctest Mail.Proplist
  alias Mail.Proplist

  describe "keys" do
    test "retrieves all keys in the specified proplist" do
      assert ["a", "b", :c] == Proplist.keys([{"a", 2}, {"b", "3"}, {:c, 4}, :d])
      # no items should result in an empty keys list
      assert [] == Proplist.keys([])
      # if the list only contains normal values, there should be no keys
      assert [] == Proplist.keys([:a, :b, :c, "a", "b", "c"])
    end
  end

  describe "has_key?" do
    test "determins if the list contains the specified key" do
      src = [{"a", 2}, {"b", "3"}, :d]
      assert true == Proplist.has_key?(src, "a")
      assert true == Proplist.has_key?(src, "b")
      # an atom as a key will not be treated as a string
      assert false == Proplist.has_key?(src, :a)
      assert false == Proplist.has_key?(src, "c")
      # bare values are not treated as keys
      assert false == Proplist.has_key?(src, :d)
    end
  end

  describe "put" do
    test "puts a key-value pair in the map" do
      # inserting a new value
      assert [{"a", 2}, {"b", 3}] == Proplist.put([{"a", 2}], "b", 3)
      # replacing an existing value
      assert [{"a", 2}, {"b", 4}] == Proplist.put([{"a", 2}, {"b", 3}], "b", 4)
    end
  end

  describe "get" do
    test "retrieves a value from the proplist" do
      # when the key exists
      assert 3 == Proplist.get([{"a", 3}, :a], "a")
      # when the key does not exist
      assert nil == Proplist.get([{"a", 3}, :a], "b")
    end
  end

  describe "merge" do
    test "concatenates two proplists (with new keys)" do
      a = [{"a", 3}, :a]
      b = [{"b", 3}, :b]

      assert [{"a", 3}, :a, {"b", 3}, :b] == Proplist.merge(a, b)
    end

    test "concatenates and overwrites keys in the first list" do
      a = [{"a", 3}, {"b", 3}, :a]
      b = [{"b", 4}, :b]

      assert [{"a", 3}, {"b", 4}, :a, :b] == Proplist.merge(a, b)
    end
  end

  describe "delete" do
    test "removes specified key from the proplist" do
      assert [{"a", 3}, :a] == Proplist.delete([{"a", 3}, {"b", 4}, :a], "b")
      assert [{"a", 3}, {"b", 4}, :a] == Proplist.delete([{"a", 3}, {"b", 4}, :a], "c")
    end
  end

  describe "drop" do
    test "removes specified keys from proplist" do
      a = [{"a", 3}, {"b", 4}, {"c", 5}, :a]

      assert [{"a", 3}, :a] == Proplist.drop(a, ["b", "c"])
    end
  end

  describe "take" do
    test "removes specified keys from proplist" do
      a = [{"a", 3}, {"b", 4}, {"c", 5}, :a]

      assert [{"b", 4}, {"c", 5}, :a] == Proplist.take(a, ["b", "c"])
    end
  end
end
