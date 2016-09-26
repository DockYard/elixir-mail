defmodule Mail.TestAssertionsTest do
  use ExUnit.Case, async: true

  test "will not raise when two multipart messages are equal" do
    message1 =
      Mail.build_multipart()
      |> Mail.put_subject("Hello")
      |> Mail.put_to("user@example.com")
      |> Mail.put_attachment("README.md")

    message2 =
      Mail.build_multipart()
      |> Mail.put_subject("Hello")
      |> Mail.put_to("user@example.com")
      |> Mail.put_attachment("README.md")

    Mail.TestAssertions.compare(message1, message2)
  end

  test "will not raise when two multipart messages have different boundaries" do
    message1 =
      Mail.build_multipart()
      |> Mail.put_subject("Hello")
      |> Mail.put_to("user@example.com")
      |> Mail.put_attachment("README.md")
      |> Mail.Message.put_content_type("multipart/alternative")
      |> Mail.Message.put_boundary("foobar")

    message2 =
      Mail.build_multipart()
      |> Mail.put_subject("Hello")
      |> Mail.put_to("user@example.com")
      |> Mail.put_attachment("README.md")
      |> Mail.Message.put_content_type("multipart/alternative")
      |> Mail.Message.put_boundary("bazqux")

    Mail.TestAssertions.compare(message1, message2)
  end

  test "will raise when a multipart message and a singlepart message are compared" do
    msg = "one message is multipart, the other is not"

    try do
      Mail.TestAssertions.compare(Mail.build(), Mail.build_multipart())
    rescue
      error in [ExUnit.AssertionError] ->
        assert msg == error.message
    end
  end

  test "will raise when two multipart messages have different number of parts" do
    message1 =
      Mail.build_multipart()
      |> Mail.put_text("Some text")
      |> Mail.put_html("<h1>Some HTML</h1>")

    message2 =
      Mail.build_multipart()
      |> Mail.put_text("Some text")

    msg = "actual and expected must have equal number of parts"

    try do
      Mail.TestAssertions.compare(message1, message2)
    rescue
      error in [ExUnit.AssertionError] ->
        assert msg == error.message
    end
  end

  test "will raise when the bodies differ" do
    message1 =
      Mail.build()
      |> Mail.put_text("Some text")

    message2 =
      Mail.build()
      |> Mail.put_text("Some other text")

    assert_raise ExUnit.AssertionError, fn ->
      Mail.TestAssertions.compare(message1, message2)
    end
  end

  test "will raise when headers differ" do
    message1 =
      Mail.build()
      |> Mail.put_subject("Test subject")

    message2 =
      Mail.build()
      |> Mail.put_subject("Other subject")

    msg = "header key `subject` is not equal"

    try do
      Mail.TestAssertions.compare(message1, message2)
    rescue
      error in [ExUnit.AssertionError] ->
        assert msg == error.message
    end
  end
end
