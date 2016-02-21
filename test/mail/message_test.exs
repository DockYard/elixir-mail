defmodule Mail.MessageTest do
  use ExUnit.Case

  test "put_part" do
    part = %Mail.Message{body: "new part"}
    message = Mail.Message.put_part(%Mail.Message{}, part)
    assert length(message.parts) == 1
    assert Enum.member?(message.parts, part)
  end

  test "delete_part" do
    message = Mail.Message.put_part(%Mail.Message{}, %Mail.Message{})
    assert length(message.parts) == 1

    part = List.first(message.parts)
    message = Mail.Message.delete_part(message, part)
    assert message.parts == []
  end

  test "ensure only `Mail.Message` structs can be used" do
    assert_raise FunctionClauseError, fn ->
      Mail.Message.put_part(%Mail.Message{}, nil)
    end
  end

  test "put_header" do
    message = Mail.Message.put_header(%Mail.Message{}, :test, "test content")
    assert message.headers.test == "test content"
  end

  test "get_header" do
    message = %Mail.Message{headers: %{foo: "bar"}}
    assert Mail.Message.get_header(message, :foo) == "bar"
  end

  test "delete_header" do
    message = Mail.Message.delete_header(%Mail.Message{headers: %{foo: "bar"}}, :foo)
    refute Map.has_key?(message.headers, :foo)
  end

  test "delete_headers" do
    message = Mail.Message.delete_headers(%Mail.Message{headers: %{foo: "bar", baz: "qux"}}, [:foo, :baz])
    refute Map.has_key?(message.headers, :foo)
    refute Map.has_key?(message.headers, :baz)
  end

  test "put_content_type" do
    message = Mail.Message.put_content_type(%Mail.Message{}, "multipart/mixed")
    assert message.headers.content_type == "multipart/mixed"
  end

  test "get_content_type" do
    message = %Mail.Message{headers: %{content_type: "multipart/mixed"}}
    assert Mail.Message.get_content_type(message) == ["multipart/mixed"]

    message = %Mail.Message{headers: %{content_type: ["multipart/mixed"]}}
    assert Mail.Message.get_content_type(message) == ["multipart/mixed"]

    message = %Mail.Message{}
    assert Mail.Message.get_content_type(message) == [""]
  end

  test "put_boundary" do
    message = Mail.Message.put_boundary(%Mail.Message{}, "customboundary")
    assert message.headers.content_type[:boundary] == "customboundary"

    message =
      Mail.Message.put_header(%Mail.Message{}, :content_type, ["multipart/mixed"])
      |> Mail.Message.put_boundary("customboundary")
    assert message.headers.content_type == ["multipart/mixed", boundary: "customboundary"]

    message =
      Mail.Message.put_header(%Mail.Message{}, :content_type, "multipart/mixed")
      |> Mail.Message.put_boundary("customboundary")
    assert message.headers.content_type == ["multipart/mixed", boundary: "customboundary"]
  end

  test "get_boundary" do
    message = Mail.Message.put_boundary(%Mail.Message{}, "customboundary")
    assert Mail.Message.get_boundary(message) == "customboundary"
    assert Mail.Message.get_boundary(%Mail.Message{}) != nil
  end

  test "put_body" do
    part = Mail.Message.put_body(%Mail.Message{}, "some body")

    assert part.body == "some body"
  end

  test "build_text" do
    message = Mail.Message.build_text("Some text")
    assert Mail.Message.get_content_type(message) == ["text/plain"]
    assert message.headers[:content_transfer_encoding] == :quoted_printable
    assert message.body == "Some text"
  end

  test "build_html" do
    message = Mail.Message.build_html("<h1>Some HTML</h1>")
    assert Mail.Message.get_content_type(message) == ["text/html"]
    assert message.headers[:content_transfer_encoding] == :quoted_printable
    assert message.body == "<h1>Some HTML</h1>"
  end

  test "build_attachment when given a path" do
    part = Mail.Message.build_attachment("README.md")
    {:ok, file_content} = File.read("README.md")

    assert Mail.Message.get_content_type(part) == ["text/markdown"]
    assert part.headers.content_disposition == [:attachment, filename: "README.md"]
    assert part.headers.content_transfer_encoding == :base64
    assert part.body == file_content
  end

  test "put_attachment when given a path" do
    part = Mail.Message.put_attachment(%Mail.Message{}, "README.md")
    {:ok, file_content} = File.read("README.md")

    assert Mail.Message.get_content_type(part) == ["text/markdown"]
    assert part.headers.content_disposition == [:attachment, filename: "README.md"]
    assert part.headers.content_transfer_encoding == :base64
    assert part.body == file_content
  end

  test "is_attachment?" do
    message = Mail.Message.build_attachment("README.md")
    assert Mail.Message.is_attachment?(message)

    message = Mail.Message.put_body(%Mail.Message{}, "test body")
    refute Mail.Message.is_attachment?(message)
  end

  test "has_attachment?" do
    message = Mail.put_text(%Mail.Message{multipart: true}, "Some text")
    refute Mail.Message.has_attachment?(message)

    message = Mail.put_attachment(message, "README.md")
    assert Mail.Message.has_attachment?(message)
  end

  test "is_text_part?" do
    message = Mail.Message.build_attachment("README.md")
    assert Mail.Message.is_attachment?(message)

    message = Mail.Message.put_body(%Mail.Message{}, "test body")
    refute Mail.Message.is_attachment?(message)
  end

  test "has_text_part" do
    message = Mail.put_attachment(%Mail.Message{multipart: true}, "README.md")
    refute Mail.Message.has_text_part?(message)

    message = Mail.put_text(message, "Some text")
    assert Mail.Message.has_text_part?(message)
  end
end
