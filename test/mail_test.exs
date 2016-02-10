defmodule MailTest do
  use ExUnit.Case
  doctest Mail

  # Build
  test "build" do
    mail = Mail.build
    assert mail == %Mail{}
  end

  # Body

  test "put_body" do
    mail = Mail.put_body(%Mail{}, :text, "test body")
    assert mail.body.text == "test body"
  end

  test "put_text" do
    mail = Mail.put_text(%Mail{}, "test text")
    assert mail.body.text == "test text"
  end

  test "put html" do
    mail = Mail.put_html(%Mail{}, "test html")
    assert mail.body.html == "test html"
  end

  # Header

  test "put_header" do
    mail = Mail.put_header(%Mail{}, :test, "test content")
    assert mail.headers.test == "test content"
  end

  test "put_subject" do
    mail = Mail.put_subject(%Mail{}, "test subject")
    assert mail.headers.subject == "test subject"
  end

  test "put_to when single recipient" do
    mail = Mail.put_to(%Mail{}, "user@example.com")
    assert mail.headers.to == ["user@example.com"]
  end

  test "put_to when multiple recipients" do
    mail = Mail.put_to(%Mail{}, ["one@example.com", "two@example.com"])
    assert mail.headers.to == ["one@example.com", "two@example.com"]
  end

  test "composing multiple `to` recipients" do
    mail =
      Mail.put_to(%Mail{}, "user@example.com")
      |> Mail.put_to(["one@example.com", "two@example.com"])

    assert mail.headers.to == ["user@example.com",
                               "one@example.com",
                               "two@example.com"]
  end

  test "can use a tuple to define `{name, email}` with `to`" do
    mail = Mail.put_to(%Mail{}, {"Test User", "user@example.com"})
    assert mail.headers.to == [{"Test User", "user@example.com"}]
  end

  test "will raise when an invalid tuple with `to`" do
    assert_raise ArgumentError, fn ->
      Mail.put_to(%Mail{}, {"Test User", "user@example.com", "other"})
    end
  end

  test "put_cc when single recipient" do
    mail = Mail.put_cc(%Mail{}, "user@example.com")
    assert mail.headers.cc == ["user@example.com"]
  end

  test "put_cc when multiple recipients" do
    mail = Mail.put_cc(%Mail{}, ["one@example.com", "two@example.com"])
    assert mail.headers.cc == ["one@example.com", "two@example.com"]
  end

  test "composing multiple `cc` recipients" do
    mail =
      Mail.put_cc(%Mail{}, "user@example.com")
      |> Mail.put_cc(["one@example.com", "two@example.com"])

    assert mail.headers.cc == ["user@example.com",
                               "one@example.com",
                               "two@example.com"]
  end

  test "can use a tuple to define `{name, email}` with `cc`" do
    mail = Mail.put_cc(%Mail{}, {"Test User", "user@example.com"})
    assert mail.headers.cc == [{"Test User", "user@example.com"}]
  end

  test "will raise when an invalid tuple with `cc`" do
    assert_raise ArgumentError, fn ->
      Mail.put_cc(%Mail{}, {"Test User", "user@example.com", "other"})
    end
  end

  test "put_bcc when single recipient" do
    mail = Mail.put_bcc(%Mail{}, "user@example.com")
    assert mail.headers.bcc == ["user@example.com"]
  end

  test "put_bcc when multiple recipients" do
    mail = Mail.put_bcc(%Mail{}, ["one@example.com", "two@example.com"])
    assert mail.headers.bcc == ["one@example.com", "two@example.com"]
  end

  test "composing multiple `bcc` recipients" do
    mail =
      Mail.put_bcc(%Mail{}, "user@example.com")
      |> Mail.put_bcc(["one@example.com", "two@example.com"])

    assert mail.headers.bcc == ["user@example.com",
                                "one@example.com",
                                "two@example.com"]
  end

  test "can use a tuple to define `{name, email}` with `bcc`" do
    mail = Mail.put_bcc(%Mail{}, {"Test User", "user@example.com"})
    assert mail.headers.bcc == [{"Test User", "user@example.com"}]
  end

  test "will raise when an invalid tuple with `bcc`" do
    assert_raise ArgumentError, fn ->
      Mail.put_bcc(%Mail{}, {"Test User", "user@example.com", "other"})
    end
  end

  test "put_from" do
    mail = Mail.put_from(%Mail{}, "user@example.com")
    assert mail.headers.from == "user@example.com"
  end

  test "put_reply_to" do
    mail = Mail.put_reply_to(%Mail{}, "other@example.com")
    assert mail.headers[:reply_to] == "other@example.com"
  end

  test "put_content_type" do
    mail = Mail.put_content_type(%Mail{}, "multipart/mixed")
    assert mail.headers[:content_type] == "multipart/mixed"
  end

  test "all_recipients combins :to, :cc, and :bcc" do
    mail =
      Mail.build
      |> Mail.put_to(["one@example.com", "two@example.com"])
      |> Mail.put_cc(["three@example.com", "one@example.com"])
      |> Mail.put_bcc(["four@example.com", "three@example.com"])

    recipients = Mail.all_recipients(mail)

    assert length(recipients) == 4
    assert Enum.member?(recipients, "one@example.com")
    assert Enum.member?(recipients, "two@example.com")
    assert Enum.member?(recipients, "three@example.com")
    assert Enum.member?(recipients, "four@example.com")
  end

  test "delete_header" do
    mail = Mail.delete_header(%Mail{headers: %{foo: "bar"}}, :foo)

    refute Map.has_key?(mail.headers, :foo)
  end

  test "delete_headers" do
    mail = Mail.delete_headers(%Mail{headers: %{foo: "bar", baz: "qux"}}, [:foo, :baz])

    refute Map.has_key?(mail.headers, :foo)
    refute Map.has_key?(mail.headers, :baz)
  end
end
