defmodule MailTest do
  use ExUnit.Case

  defmodule TestRenderer do
    def render(message) do
      Mail.Message.get_header(message, :subject)
    end
  end

  test "build" do
    assert Mail.build() == %Mail.Message{}
  end

  test "build_multipart" do
    assert Mail.build_multipart() == %Mail.Message{multipart: true}
  end

  test "put_subject" do
    mail = Mail.put_subject(Mail.build(), "test subject")
    assert mail.headers.subject == "test subject"
  end

  test "put_to when single recipient" do
    mail = Mail.put_to(Mail.build(), "user@example.com")
    assert mail.headers.to == ["user@example.com"]
  end

  test "put_to when multiple recipients" do
    mail = Mail.put_to(Mail.build(), ["one@example.com", "two@example.com"])
    assert mail.headers.to == ["one@example.com", "two@example.com"]
  end

  test "composing multiple `to` recipients" do
    mail =
      Mail.put_to(Mail.build(), "user@example.com")
      |> Mail.put_to(["one@example.com", "two@example.com"])

    assert mail.headers.to == ["user@example.com",
                               "one@example.com",
                               "two@example.com"]
  end

  test "can use a tuple to define `{name, email}` with `to`" do
    mail = Mail.put_to(Mail.build(), {"Test User", "user@example.com"})
    assert mail.headers.to == [{"Test User", "user@example.com"}]
  end

  test "will raise when an invalid tuple with `to`" do
    assert_raise ArgumentError, fn ->
      Mail.put_to(Mail.build(), {"Test User", "user@example.com", "other"})
    end
  end

  test "put_cc when single recipient" do
    mail = Mail.put_cc(Mail.build(), "user@example.com")
    assert mail.headers.cc == ["user@example.com"]
  end

  test "put_cc when multiple recipients" do
    mail = Mail.put_cc(Mail.build(), ["one@example.com", "two@example.com"])
    assert mail.headers.cc == ["one@example.com", "two@example.com"]
  end

  test "composing multiple `cc` recipients" do
    mail =
      Mail.put_cc(Mail.build(), "user@example.com")
      |> Mail.put_cc(["one@example.com", "two@example.com"])

    assert mail.headers.cc == ["user@example.com",
                               "one@example.com",
                               "two@example.com"]
  end

  test "can use a tuple to define `{name, email}` with `cc`" do
    mail = Mail.put_cc(Mail.build(), {"Test User", "user@example.com"})
    assert mail.headers.cc == [{"Test User", "user@example.com"}]
  end

  test "will raise when an invalid tuple with `cc`" do
    assert_raise ArgumentError, fn ->
      Mail.put_cc(Mail.build(), {"Test User", "user@example.com", "other"})
    end
  end

  test "put_bcc when single recipient" do
    mail = Mail.put_bcc(Mail.build(), "user@example.com")
    assert mail.headers.bcc == ["user@example.com"]
  end

  test "put_bcc when multiple recipients" do
    mail = Mail.put_bcc(Mail.build(), ["one@example.com", "two@example.com"])
    assert mail.headers.bcc == ["one@example.com", "two@example.com"]
  end

  test "composing multiple `bcc` recipients" do
    mail =
      Mail.put_bcc(Mail.build(), "user@example.com")
      |> Mail.put_bcc(["one@example.com", "two@example.com"])

    assert mail.headers.bcc == ["user@example.com",
                                "one@example.com",
                                "two@example.com"]
  end

  test "can use a tuple to define `{name, email}` with `bcc`" do
    mail = Mail.put_bcc(Mail.build(), {"Test User", "user@example.com"})
    assert mail.headers.bcc == [{"Test User", "user@example.com"}]
  end

  test "will raise when an invalid tuple with `bcc`" do
    assert_raise ArgumentError, fn ->
      Mail.put_bcc(Mail.build(), {"Test User", "user@example.com", "other"})
    end
  end

  test "put_from" do
    mail = Mail.put_from(Mail.build(), "user@example.com")
    assert mail.headers.from == "user@example.com"
  end

  test "put_reply_to" do
    mail = Mail.put_reply_to(Mail.build(), "other@example.com")
    assert mail.headers[:reply_to] == "other@example.com"
  end

  test "all_recipients combins :to, :cc, and :bcc" do
    mail =
      Mail.put_to(Mail.build(), ["one@example.com", "two@example.com"])
      |> Mail.put_cc(["three@example.com", "one@example.com"])
      |> Mail.put_bcc(["four@example.com", "three@example.com"])

    recipients = Mail.all_recipients(mail)

    assert length(recipients) == 4
    assert Enum.member?(recipients, "one@example.com")
    assert Enum.member?(recipients, "two@example.com")
    assert Enum.member?(recipients, "three@example.com")
    assert Enum.member?(recipients, "four@example.com")
  end

  test "put_text with a singlepart" do
    mail = Mail.put_text(Mail.build(), "Some text")

    assert length(mail.parts) == 0
    assert mail.body == "Some text"
    assert Mail.Message.get_content_type(mail) == ["text/plain"]
  end

  test "put_text with a multipart" do
    mail = Mail.put_text(Mail.build_multipart(), "Some text")

    assert length(mail.parts) == 1
    part = List.first(mail.parts)

    assert part.body == "Some text"
    assert Mail.Message.get_content_type(part) == ["text/plain"]
  end

  test "put_text replaces existing text part in multipart" do
    mail =
      Mail.put_text(Mail.build_multipart(), "Some text")
      |> Mail.put_text("Some other text")

    assert length(mail.parts) == 1
    part = List.first(mail.parts)

    assert part.body == "Some other text"
    assert Mail.Message.get_content_type(part) == ["text/plain"]
  end

  test "get_text with singlepart" do
    mail = Mail.put_text(Mail.build(), "Some text")
    assert Mail.get_text(mail) == mail
  end

  test "get_text with singlepart not text" do
    mail = Mail.put_html(Mail.build(), "<h1>Some HTML</h1>")
    assert is_nil(Mail.get_text(mail))
  end

  test "get_text with a multipart" do
    mail = Mail.put_text(Mail.build_multipart(), "Some text")

    text_part = Mail.get_text(mail)

    assert text_part.body == "Some text"
  end

  test "get_text with multipart not text" do
    mail = Mail.put_html(Mail.build_multipart(), "<h1>Some HTML</h1>")
    assert is_nil(Mail.get_text(mail))
  end

  test "put_html with a singlepart" do
    mail = Mail.put_html(Mail.build(), "<h1>Some HTML</h1>")

    assert length(mail.parts) == 0
    assert mail.body == "<h1>Some HTML</h1>"
    assert Mail.Message.get_content_type(mail) == ["text/html"]
  end

  test "put_html with a multipart" do
    mail = Mail.put_html(Mail.build_multipart(), "<h1>Some HTML</h1>")

    assert length(mail.parts) == 1
    part = List.first(mail.parts)

    assert part.body == "<h1>Some HTML</h1>"
    assert Mail.Message.get_content_type(part) == ["text/html"]
  end

  test "put_html replaces existing html part in multipart" do
    mail =
      Mail.put_html(Mail.build_multipart(), "<h1>Some HTML</h1>")
      |> Mail.put_html("<h1>Some other html</h1>")

    assert length(mail.parts) == 1
    part = List.first(mail.parts)

    assert part.body == "<h1>Some other html</h1>"
    assert Mail.Message.get_content_type(part) == ["text/html"]
  end

  test "get_html with singlepart" do
    mail = Mail.put_html(Mail.build(), "<h1>Some HTML</h1>")
    assert Mail.get_html(mail) == mail
  end

  test "get_html with singlepart not html" do
    mail = Mail.put_text(Mail.build(), "Some text")
    assert is_nil(Mail.get_html(mail))
  end

  test "get_html with a multipart" do
    mail = Mail.put_html(Mail.build_multipart(), "<h1>Some HTML</h1>")

    html_part = Mail.get_html(mail)

    assert html_part.body == "<h1>Some HTML</h1>"
  end

  test "get_html with multipart not html" do
    mail = Mail.put_text(Mail.build_multipart(), "Some text")
    assert is_nil(Mail.get_html(mail))
  end

  test "put_attachment with a simglepart" do
    mail = Mail.put_attachment(Mail.build(), "README.md")

    assert Enum.empty?(mail.parts)

    {:ok, file_content} = File.read("README.md")

    assert Mail.Message.get_content_type(mail) == ["text/markdown"]
    assert mail.headers.content_disposition == [:attachment, filename: "README.md"]
    assert mail.headers.content_transfer_encoding == :base64
    assert mail.body == file_content
  end

  test "put_attachment with a multipart" do
    mail = Mail.put_attachment(Mail.build_multipart(), "README.md")

    assert length(mail.parts) == 1
    part = List.first(mail.parts)

    {:ok, file_content} = File.read("README.md")

    assert Mail.Message.get_content_type(part) == ["text/markdown"]
    assert part.headers.content_disposition == [:attachment, filename: "README.md"]
    assert part.headers.content_transfer_encoding == :base64
    assert part.body == file_content
  end

  test "renders with the given renderer" do
    result =
      Mail.build()
      |> Mail.put_subject("Test!")
      |> Mail.render(TestRenderer)

    assert result == "Test!"
  end
end
