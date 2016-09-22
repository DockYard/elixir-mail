defmodule Mail.Parsers.RFC2822Test do
  use ExUnit.Case

  test "parses a singlepart message" do
    mail = """
    To: user@example.com
    From: me@example.com
    Subject: Test Email
    Content-Type: text/plain; foo=bar;
      baz=qux

    This is the body!
    """
    |> String.replace("\n", "\r\n")

    message = Mail.Parsers.RFC2822.parse(mail)

    assert message.headers[:to] == ["user@example.com"]
    assert message.headers[:from] == "me@example.com"
    assert message.headers[:subject] == "Test Email"
    assert message.headers[:content_type] == ["text/plain", foo: "bar", baz: "qux"]
    assert message.body == "This is the body!"
  end

  test "parses a multipart message" do
    mail = """
    To: Test User <user@example.com>, Other User <other@example.com>
    CC: The Dude <dude@example.com>, Batman <batman@example.com>
    From: Me <me@example.com>
    Subject: Test email
    Mime-Version: 1.0
    Content-Type: multipart/alternative; boundary=foobar

    --foobar
    Content-Type: text/plain

    This is some text

    --foobar
    Content-Type: text/html

    <h1>This is some HTML</h1>
    --foobar--
    """
    |> String.replace("\n", "\r\n")

    message = Mail.Parsers.RFC2822.parse(mail)

    assert message.headers[:to] == [{"Test User", "user@example.com"}, {"Other User", "other@example.com"}]
    assert message.headers[:cc] == [{"The Dude", "dude@example.com"}, {"Batman", "batman@example.com"}]
    assert message.headers[:from] == {"Me", "me@example.com"}
    assert message.headers[:content_type] == ["multipart/alternative", boundary: "foobar"]

    [text_part, html_part] = message.parts

    assert text_part.headers[:content_type] == "text/plain"
    assert text_part.body == "This is some text"

    assert html_part.headers[:content_type] == "text/html"
    assert html_part.body == "<h1>This is some HTML</h1>"
  end

  test "erl_from_timestamp\1" do
    date_time = Mail.Parsers.RFC2822.erl_from_timestamp("Fri, 1 Jan 2016 00:00:00 +0000")

    assert date_time == {{2016, 1, 1}, {0,0,0}}
  end

  test "parses a nested multipart message with encoded part" do
    mail = """
    To: Test User <user@example.com>, Other User <other@example.com>
    CC: The Dude <dude@example.com>, Batman <batman@example.com>
    From: Me <me@example.com>
    Content-Type: multipart/mixed; boundary="foobar"
    Date: Fri, 1 Jan 2016 00:00:00 +0000

    --foobar
    Content-Type: multipart/alternative; boundary="bazqux"

    --bazqux
    Content-Type: text/plain

    This is some text

    --bazqux
    Content-Type: text/html

    <h1>This is the HTML</h1>

    --bazqux--
    --foobar
    Content-Type: text/markdown
    Content-Disposition: attachment; filename=README.md
    Content-Transfer-Encoding: base64

    SGVsbG8gd29ybGQh
    --foobar--
    """
    |> String.replace("\n", "\r\n")

    message = Mail.Parsers.RFC2822.parse(mail)

    assert message.headers[:to] == [{"Test User", "user@example.com"}, {"Other User", "other@example.com"}]
    assert message.headers[:cc] == [{"The Dude", "dude@example.com"}, {"Batman", "batman@example.com"}]
    assert message.headers[:from] == {"Me", "me@example.com"}
    assert message.headers[:content_type] == ["multipart/mixed", boundary: "foobar"]
    assert message.headers[:date] == {{2016,1,1},{0,0,0}}

    [alt_part, attach_part] = message.parts

    assert alt_part.headers[:content_type] == ["multipart/alternative", boundary: "bazqux"]
    [text_part, html_part] = alt_part.parts

    assert text_part.headers[:content_type] == "text/plain"
    assert text_part.body == "This is some text"

    assert html_part.headers[:content_type] == "text/html"
    assert html_part.body == "<h1>This is the HTML</h1>"

    assert attach_part.headers[:content_type] == "text/markdown"
    assert attach_part.headers[:content_disposition] == ["attachment", filename: "README.md"]
    assert attach_part.headers[:content_transfer_encoding] == "base64"
    assert attach_part.body == "Hello world!"
  end
end
