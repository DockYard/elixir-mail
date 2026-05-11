defmodule Mail.HeadersTest do
  use ExUnit.Case, async: true

  test "normalizes header names" do
    assert Mail.Headers.normalize_name("Content_Type") == "content-type"
    assert Mail.Headers.normalize_name(:content_type) == "content-type"
  end

  test "put/3 replaces all instances and keeps order" do
    headers =
      Mail.Headers.new()
      |> Mail.Headers.append("x-test", "a")
      |> Mail.Headers.append("x-test", "b")
      |> Mail.Headers.put("x-test", "c")

    assert Mail.Headers.to_list(headers) == [{"x-test", "c"}]
    assert Mail.Headers.values(headers, "x-test") == ["c"]
  end

  test "prepend/3 allows duplicates" do
    headers =
      Mail.Headers.new()
      |> Mail.Headers.append("x-test", "a")
      |> Mail.Headers.prepend("x-test", "b")

    assert Mail.Headers.to_list(headers) == [{"x-test", "b"}, {"x-test", "a"}]
    assert Mail.Headers.values(headers, "x-test") == ["b", "a"]
  end

  test "prepend_headers/2 preserves source order and duplicates before target" do
    target =
      Mail.Headers.new()
      |> Mail.Headers.append("content-type", "multipart/mixed")

    source =
      Mail.Headers.new()
      |> Mail.Headers.append("received", "hop-a")
      |> Mail.Headers.append("received", "hop-b")
      |> Mail.Headers.append("subject", "hi")

    merged = Mail.Headers.prepend_headers(target, source)

    assert Mail.Headers.to_list(merged) == [
             {"received", "hop-a"},
             {"received", "hop-b"},
             {"subject", "hi"},
             {"content-type", "multipart/mixed"}
           ]
  end

  test "Access: missing returns nil, single returns value, multiple returns list" do
    empty = Mail.Headers.new()
    assert empty["x-test"] == nil

    single = Mail.Headers.put(empty, "x-test", "a")
    assert single["x-test"] == "a"

    multiple =
      single
      |> Mail.Headers.append("x-test", "b")

    assert multiple["x-test"] == ["a", "b"]
  end

  describe "Access callbacks" do
    test "fetch/2" do
      headers =
        Mail.Headers.new()
        |> Mail.Headers.append("x-test", "a")
        |> Mail.Headers.append("x-test", "b")
        |> Mail.Headers.append("y-test", "y")

      assert Access.fetch(headers, "missing") == :error
      assert Access.fetch(headers, "y-test") == {:ok, "y"}
      assert Access.fetch(headers, "x-test") == {:ok, ["a", "b"]}
    end

    test "get_and_update/3" do
      headers =
        Mail.Headers.new()
        |> Mail.Headers.append("x-test", "a")
        |> Mail.Headers.append("x-test", "b")
        |> Mail.Headers.append("y-test", "y")

      {get, updated} =
        Access.get_and_update(headers, "y-test", fn current ->
          {current, "y2"}
        end)

      assert get == "y"
      assert updated["y-test"] == "y2"
    end

    test "pop/2" do
      headers =
        Mail.Headers.new()
        |> Mail.Headers.append("x-test", "a")
        |> Mail.Headers.append("x-test", "b")
        |> Mail.Headers.append("y-test", "y")

      {popped, after_pop} = Access.pop(headers, "x-test")
      assert popped == ["a", "b"]
      assert after_pop["x-test"] == nil
    end
  end

  describe "Enumerable" do
    test "Enum.to_list/1" do
      headers =
        Mail.Headers.new()
        |> Mail.Headers.append("a", 1)
        |> Mail.Headers.append("b", 2)

      assert Enum.to_list(headers) == [{"a", 1}, {"b", 2}]
    end

    test "Enum.count/1" do
      headers =
        Mail.Headers.new()
        |> Mail.Headers.append("a", 1)
        |> Mail.Headers.append("b", 2)

      assert Enum.count(headers) == 2
    end

    test "Enum.member?/2" do
      headers =
        Mail.Headers.new()
        |> Mail.Headers.append("a", 1)
        |> Mail.Headers.append("b", 2)

      assert Enum.member?(headers, {"a", 1})
      refute Enum.member?(headers, {"a", 2})
    end
  end

  test "get_single!/2 returns singleton or nil and raises on duplicates" do
    headers = Mail.Headers.new()
    assert Mail.Headers.get_single!(headers, "x-test") == nil

    headers = Mail.Headers.put(headers, "x-test", "a")
    assert Mail.Headers.get_single!(headers, "x-test") == "a"

    headers = Mail.Headers.append(headers, "x-test", "b")

    assert_raise ArgumentError, fn ->
      Mail.Headers.get_single!(headers, "x-test")
    end
  end
end
