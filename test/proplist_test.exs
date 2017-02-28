defmodule Mail.ProplistTest do
  use ExUnit.Case, async: true
  doctest Mail.Proplist
  alias Mail.Proplist

  describe "keys" do
    test "retrieves all keys in the specified proplist" do
      a = [{"a", 2}, {"b", "3"}, {:c, 4}, :d]

      assert ["a", "b", :c] == Proplist.keys(a)
    end
  end

  describe "put" do
    test "puts a key-value pair in the map" do
      a = [{"a", 2}]
      assert [{"a", 2}, {"b", 3}] == Proplist.put(a, "b", 3)
    end
  end

  describe "get" do
    test "retrieves a value from the proplist" do
      a = [{"a", 3}, :a]

      assert 3 == Proplist.get(a, "a")
    end
  end

  describe "merge" do
    test "concatenates two proplists" do
      a = [{"a", 3}, :a]
      b = [{"b", 3}, :b]

      assert [{"a", 3}, :a, {"b", 3}, :b] == Proplist.merge(a, b)
    end
  end

  describe "delete" do
    test "concatenates two proplists" do
      a = [{"a", 3}, {"b", 4}, :a]

      assert [{"a", 3}, :a] == Proplist.delete(a, "b")
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
