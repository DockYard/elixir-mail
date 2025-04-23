defmodule Mail.MessageTest do
  use ExUnit.Case, async: true
  doctest Mail.Message

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

  test "put_header" do
    message = Mail.Message.put_header(%Mail.Message{}, :test, "test content")
    assert Mail.Message.get_header(message, :test) == "test content"
  end

  test "get_header" do
    message = %Mail.Message{headers: %{"foo" => "bar"}}
    assert Mail.Message.get_header(message, :foo) == "bar"
  end

  test "delete_header" do
    message = Mail.Message.delete_header(%Mail.Message{headers: %{"foo" => "bar"}}, :foo)
    refute Map.has_key?(message.headers, :foo)
  end

  test "delete_headers" do
    message =
      Mail.Message.delete_headers(%Mail.Message{headers: %{"foo" => "bar", "baz" => "qux"}}, [
        :foo,
        :baz
      ])

    refute Mail.Message.has_header?(message, :foo)
    refute Mail.Message.has_header?(message, :baz)
  end

  test "put_content_type" do
    message = Mail.Message.put_content_type(%Mail.Message{}, "multipart/mixed")
    assert Mail.Message.get_header(message, :content_type) == ["multipart/mixed"]
  end

  test "get_content_type" do
    message = %Mail.Message{headers: %{"content-type" => "multipart/mixed"}}
    assert Mail.Message.get_content_type(message) == ["multipart/mixed"]

    message = %Mail.Message{headers: %{"content-type" => ["multipart/mixed"]}}
    assert Mail.Message.get_content_type(message) == ["multipart/mixed"]

    message = %Mail.Message{}
    assert Mail.Message.get_content_type(message) == [""]
  end

  test "put_boundary" do
    message = Mail.Message.put_boundary(%Mail.Message{}, "customboundary")

    boundary =
      message
      |> Mail.Message.get_header(:content_type)
      |> Mail.Proplist.get("boundary")

    assert boundary == "customboundary"

    message =
      Mail.Message.put_header(%Mail.Message{}, :content_type, ["multipart/mixed"])
      |> Mail.Message.put_boundary("customboundary")

    assert Mail.Message.get_header(message, :content_type) == [
             "multipart/mixed",
             {"boundary", "customboundary"}
           ]

    message =
      Mail.Message.put_header(%Mail.Message{}, :content_type, "multipart/mixed")
      |> Mail.Message.put_boundary("customboundary")

    assert Mail.Message.get_header(message, :content_type) == [
             "multipart/mixed",
             {"boundary", "customboundary"}
           ]
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
    assert Mail.Message.get_content_type(message) == ["text/plain", {"charset", "UTF-8"}]
    assert Mail.Message.get_header(message, :content_transfer_encoding) == :quoted_printable
    assert message.body == "Some text"
  end

  test "build_text when given charset" do
    message = Mail.Message.build_text("Some text", charset: "US-ASCII")
    assert Mail.Message.get_content_type(message) == ["text/plain", {"charset", "US-ASCII"}]
    assert Mail.Message.get_header(message, :content_transfer_encoding) == :quoted_printable
    assert message.body == "Some text"
  end

  test "build_html" do
    message = Mail.Message.build_html("<h1>Some HTML</h1>")
    assert Mail.Message.get_content_type(message) == ["text/html", {"charset", "UTF-8"}]
    assert Mail.Message.get_header(message, :content_transfer_encoding) == :quoted_printable
    assert message.body == "<h1>Some HTML</h1>"
  end

  test "build_html when given charset" do
    message = Mail.Message.build_html("<h1>Some HTML</h1>", charset: "US-ASCII")
    assert Mail.Message.get_content_type(message) == ["text/html", {"charset", "US-ASCII"}]
    assert Mail.Message.get_header(message, :content_transfer_encoding) == :quoted_printable
    assert message.body == "<h1>Some HTML</h1>"
  end

  test "build_attachment when given a path" do
    part = Mail.Message.build_attachment("README.md")
    {:ok, file_content} = File.read("README.md")

    assert Mail.Message.get_content_type(part) == ["text/markdown"]

    assert Mail.Message.get_header(part, :content_disposition) == [
             "attachment",
             {"filename", "README.md"}
           ]

    assert Mail.Message.get_header(part, :content_transfer_encoding) == :base64
    assert part.body == file_content
  end

  test "build_attachment when given a path with headers" do
    part = Mail.Message.build_attachment("README.md", headers: [content_id: "attachment-id"])
    {:ok, file_content} = File.read("README.md")

    assert Mail.Message.get_content_type(part) == ["text/markdown"]

    assert Mail.Message.get_header(part, :content_disposition) == [
             "attachment",
             {"filename", "README.md"}
           ]

    assert Mail.Message.get_header(part, :content_transfer_encoding) == :base64
    assert Mail.Message.get_header(part, :content_id) == "attachment-id"
    assert part.body == file_content
  end

  test "put_attachment when given a path" do
    part = Mail.Message.put_attachment(%Mail.Message{}, "README.md")
    {:ok, file_content} = File.read("README.md")

    assert Mail.Message.get_content_type(part) == ["text/markdown"]

    assert Mail.Message.get_header(part, :content_disposition) == [
             "attachment",
             {"filename", "README.md"}
           ]

    assert Mail.Message.get_header(part, :content_transfer_encoding) == :base64
    assert part.body == file_content
  end

  test "put_attachment when given a path with headers" do
    part =
      Mail.Message.put_attachment(%Mail.Message{}, "README.md",
        headers: [content_id: "attachment-id"]
      )

    {:ok, file_content} = File.read("README.md")

    assert Mail.Message.get_content_type(part) == ["text/markdown"]

    assert Mail.Message.get_header(part, :content_disposition) == [
             "attachment",
             {"filename", "README.md"}
           ]

    assert Mail.Message.get_header(part, :content_transfer_encoding) == :base64
    assert Mail.Message.get_header(part, :content_id) == "attachment-id"
    assert part.body == file_content
  end

  test "is_attachment?" do
    message = Mail.Message.build_attachment("README.md")
    assert Mail.Message.is_attachment?(message)

    message = Mail.Message.put_body(%Mail.Message{}, "test body")
    refute Mail.Message.is_attachment?(message)
  end

  test "is_text_part?" do
    message = Mail.Message.build_attachment("README.md")
    assert Mail.Message.is_attachment?(message)

    message = Mail.Message.put_body(%Mail.Message{}, "test body")
    refute Mail.Message.is_attachment?(message)
  end

  test "UTF-8 in subject" do
    subject = "test üä test"

    txt =
      Mail.build()
      |> Mail.put_subject(subject)
      |> Mail.render()

    encoded_subject = "=?UTF-8?Q?" <> Mail.Encoders.QuotedPrintable.encode(subject) <> "?="

    assert String.contains?(txt, encoded_subject)
    assert %Mail.Message{headers: %{"subject" => ^subject}} = Mail.Parsers.RFC2822.parse(txt)
  end

  test "UTF-8 in subject (quoted printable with spaces, RFC 2047§4.2 (2))" do
    subject = "test 😀 test"

    mail =
      "Subject: =?UTF-8?Q?test_" <> Mail.Encoders.QuotedPrintable.encode("😀") <> "_test?=\r\n\r\n"

    assert %Mail.Message{headers: %{"subject" => ^subject}} = Mail.Parsers.RFC2822.parse(mail)
  end

  test "UTF-8 in addresses" do
    from = {"Joachim Löw", "joachim.loew@example.com"}
    to = {"Wolfgang Schüler", "wolfgang.schueler@example.com"}

    txt =
      Mail.build()
      |> Mail.put_from(from)
      |> Mail.put_to(to)
      |> Mail.render()

    encoded_from =
      ~s(From: =?UTF-8?Q?"#{Mail.Encoders.QuotedPrintable.encode(elem(from, 0))}"?= <#{elem(from, 1)}>)

    encoded_to =
      ~s(To: =?UTF-8?Q?"#{Mail.Encoders.QuotedPrintable.encode(elem(to, 0))}"?= <#{elem(to, 1)}>)

    assert txt =~ encoded_from
    assert txt =~ encoded_to
  end

  test "UTF-8 in other header" do
    file_name = "READMEüä.md"

    message =
      Mail.build()
      |> Mail.put_attachment({file_name, "data"}, headers: [content_id: "attachment-id"])
      |> Mail.render()

    encoded_header_value =
      "=?UTF-8?Q?" <> Mail.Encoders.QuotedPrintable.encode("READMEüä.md") <> "?="

    assert String.contains?(message, encoded_header_value)

    assert %Mail.Message{
             headers: %{"content-disposition" => ["attachment", {"filename", ^file_name}]}
           } = Mail.Parsers.RFC2822.parse(message)
  end

  test "long UTF-8 in subject" do
    subject =
      "über alles\nnew ?= line some очень-очень-очень-очень-очень-очень-очень-очень-очень-очень-очень-очень long line"

    txt =
      Mail.build()
      |> Mail.put_subject(subject)
      |> Mail.render()

    encoded_subject =
      "=?UTF-8?Q?=C3=BCber alles=0Anew =3F=3D line some =D0=BE=D1=87=D0=B5=D0=BD?==?UTF-8?Q?=D1=8C-=D0=BE=D1=87=D0=B5=D0=BD=D1=8C-=D0=BE=D1=87=D0=B5=D0=BD?==?UTF-8?Q?=D1=8C-=D0=BE=D1=87=D0=B5=D0=BD=D1=8C-=D0=BE=D1=87=D0=B5=D0=BD?==?UTF-8?Q?=D1=8C-=D0=BE=D1=87=D0=B5=D0=BD=D1=8C-=D0=BE=D1=87=D0=B5=D0=BD?==?UTF-8?Q?=D1=8C-=D0=BE=D1=87=D0=B5=D0=BD=D1=8C-=D0=BE=D1=87=D0=B5=D0=BD?==?UTF-8?Q?=D1=8C-=D0=BE=D1=87=D0=B5=D0=BD=D1=8C-=D0=BE=D1=87=D0=B5=D0=BD?==?UTF-8?Q?=D1=8C-=D0=BE=D1=87=D0=B5=D0=BD=D1=8C long line?="

    assert String.contains?(txt, encoded_subject)
    assert %Mail.Message{headers: %{"subject" => ^subject}} = Mail.Parsers.RFC2822.parse(txt)
  end

  test "headers in message are rendered correctly" do
    message =
      %Mail.Message{
        headers: %{
          "from" => "\"Sender\" <sender@example.com>",
          "subject" => "Test Subject",
          "to" => [{"", "recipient@example.com"}],
          "x-custom-header-1" => "custom-header-value",
          "x-custom-header-2" => "custom-header-value"
        },
        body: nil,
        parts: [
          %Mail.Message{
            headers: %{
              "content-transfer-encoding" => :quoted_printable,
              "content-type" => ["text/plain", {"charset", "utf-8"}]
            },
            body: "Test text body",
            parts: [],
            multipart: false
          }
        ],
        multipart: false
      }

    rendered = Mail.Renderers.RFC2822.render(message)
    assert String.contains?(rendered, "X-Custom-Header-1")
    assert String.contains?(rendered, "X-Custom-Header-2")
  end

  test "headers in multipart message are rendered correctly" do
    message =
      %Mail.Message{
        headers: %{
          "from" => "\"Sender\" <sender@example.com>",
          "subject" => "Test Subject",
          "to" => [{"", "recipient@example.com"}],
          "x-custom-header-1" => "custom-header-value",
          "x-custom-header-2" => "custom-header-value"
        },
        body: nil,
        parts: [
          %Mail.Message{
            headers: %{
              "content-transfer-encoding" => :quoted_printable,
              "content-type" => ["text/plain", {"charset", "utf-8"}]
            },
            body: "Test text body",
            parts: [],
            multipart: false
          },
          %Mail.Message{
            headers: %{
              "content-transfer-encoding" => :quoted_printable,
              "content-type" => ["text/html", {"charset", "UTF-8"}]
            },
            body: "<html>html body</html>",
            parts: [],
            multipart: false
          }
        ],
        multipart: true
      }

    rendered = Mail.Renderers.RFC2822.render(message)
    assert String.contains?(rendered, "X-Custom-Header-1")
    assert String.contains?(rendered, "X-Custom-Header-2")
  end
end
