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

    encoded_subject = "=?UTF-8?Q?" <> String.replace(Mail.Encoders.QuotedPrintable.encode(subject), " ", "_") <> "?="

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
      ~s(From: =?UTF-8?Q?"#{elem(from, 0) |> Mail.Encoders.QuotedPrintable.encode() |> String.replace(" ", "_")}"?= <#{elem(from, 1)}>)

    encoded_to =
      ~s(To: =?UTF-8?Q?"#{elem(to, 0) |> Mail.Encoders.QuotedPrintable.encode() |> String.replace(" ", "_")}"?= <#{elem(to, 1)}>)

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
    # begin value with simple ASCII so each character is encoded into a single character
    subject =
      "123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890 über alles\nnew ?= line some очень-очень-очень-очень-очень-очень-очень-очень-очень-очень-очень-очень long line"

    txt =
      Mail.build()
      |> Mail.put_subject(subject)
      |> Mail.render()

    # Each encoded word has a maximum length of 75 characters, minus the wrapping
    # 12 characters for the wrapping, that leaves 63 characters internally.  The
    # first line's header is 7 characters plus 1 space and 1 colon, so that leaves
    # 54 internal charcaters within the encoded word
    encoded_subject =
      """
      Subject: =?UTF-8?Q?123456789012345678901234567890123456789012345678901234?=
       =?UTF-8?Q?567890123456789012345678901234567890123456789012345678901234567?=
       =?UTF-8?Q?890_=C3=BCber_alles=0Anew_=3F=3D_line_some_=D0=BE=D1=87=D0=B5?=
       =?UTF-8?Q?=D0=BD=D1=8C-=D0=BE=D1=87=D0=B5=D0=BD=D1=8C-=D0=BE=D1=87=D0=B5?=
       =?UTF-8?Q?=D0=BD=D1=8C-=D0=BE=D1=87=D0=B5=D0=BD=D1=8C-=D0=BE=D1=87=D0=B5?=
       =?UTF-8?Q?=D0=BD=D1=8C-=D0=BE=D1=87=D0=B5=D0=BD=D1=8C-=D0=BE=D1=87=D0=B5?=
       =?UTF-8?Q?=D0=BD=D1=8C-=D0=BE=D1=87=D0=B5=D0=BD=D1=8C-=D0=BE=D1=87=D0=B5?=
       =?UTF-8?Q?=D0=BD=D1=8C-=D0=BE=D1=87=D0=B5=D0=BD=D1=8C-=D0=BE=D1=87=D0=B5?=
       =?UTF-8?Q?=D0=BD=D1=8C-=D0=BE=D1=87=D0=B5=D0=BD=D1=8C_long_line?=
      """
      |> String.replace("\n", "\r\n")

    assert String.contains?(txt, encoded_subject)
    assert %Mail.Message{headers: %{"subject" => ^subject}} = Mail.Parsers.RFC2822.parse(txt)
  end

  test "UTF-8 in header with extremely long name" do
    header_name = "x-this-is-a-ridiculously-long-header-value-that-should-never-happen-in-practice"
    value = "123太长了"

    txt =
      Mail.build()
      |> Mail.Message.put_header(header_name, value)
      |> Mail.render()

    # Header is too long, so initial value is an empty encoded word of "=?UTF-8?Q??=".
    encoded_header =
      """
      X-This-Is-A-Ridiculously-Long-Header-Value-That-Should-Never-Happen-In-Practice: =?UTF-8?Q??=
       =?UTF-8?Q?123=E5=A4=AA=E9=95=BF=E4=BA=86?=
      """
      |> String.replace("\n", "\r\n")

    assert String.contains?(txt, encoded_header)
    assert %Mail.Message{headers: %{^header_name => ^value}} = Mail.Parsers.RFC2822.parse(txt)
  end

  test "simple ASCII in subject that's folded" do
    subject =
      "Here's some regular text that contains enough characters that the header should be wrapped."

    txt =
      Mail.build()
      |> Mail.put_subject(subject)
      |> Mail.render()

    # Each line has a maximum desired length of 78 characters (excluding trailing CRLF).
    encoded_subject =
      """
      Subject: Here's some regular text that contains enough characters that the
       header should be wrapped.
      """
      |> String.replace("\n", "\r\n")

    assert String.contains?(txt, encoded_subject)
    assert %Mail.Message{headers: %{"subject" => ^subject}} = Mail.Parsers.RFC2822.parse(txt)
  end

  test "long ASCII chunk in subject" do
    subject =
      "12345678901234567890123456789012345678901234567890123456789012345678901234567890 1234567890123456789012345678901234567890 Here's some regular text that continue to yet another line"

    txt =
      Mail.build()
      |> Mail.put_subject(subject)
      |> Mail.render()

    # Each line has a maximum desired length of 78 characters (excluding trailing CRLF).
    encoded_subject =
      """
      Subject: 12345678901234567890123456789012345678901234567890123456789012345678901234567890
       1234567890123456789012345678901234567890 Here's some regular text that
       continue to yet another line
      """
      |> String.replace("\n", "\r\n")

    assert String.contains?(txt, encoded_subject)
    assert %Mail.Message{headers: %{"subject" => ^subject}} = Mail.Parsers.RFC2822.parse(txt)
  end

  test "ASCII in header with extremely long name" do
    header_name = "x-this-is-a-ridiculously-long-header-value-that-should-never-happen-in-practice"
    value = "123 too long"

    txt =
      Mail.build()
      |> Mail.Message.put_header(header_name, value)
      |> Mail.render()

    # header is too long, so header is folded on the next available foldable whitespace
    encoded_header =
      """
      X-This-Is-A-Ridiculously-Long-Header-Value-That-Should-Never-Happen-In-Practice: 123
       too long
      """
      |> String.replace("\n", "\r\n")

    assert String.contains?(txt, encoded_header)
    assert %Mail.Message{headers: %{^header_name => ^value}} = Mail.Parsers.RFC2822.parse(txt)
  end
end
