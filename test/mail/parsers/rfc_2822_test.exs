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

  test "erl_from_timestamp\1 with CRLF in date string" do
    date_time = Mail.Parsers.RFC2822.erl_from_timestamp("Fri, 1 Jan\r\n 2016 00:00:00 +0000")

    assert date_time == {{2016, 1, 1}, {0,0,0}}
  end

  test "erl_from_timestamp\1 day of week optional" do
    date_time = Mail.Parsers.RFC2822.erl_from_timestamp("1 Jan 2016 00:00:00 +0000")

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

  test "parses unstructured headers" do
    mail = """
    Delivered-To: user@example.com
    Received: by 101.102.103.104 with SMTP id abcdefg;
            Fri, 1 Apr 2016 11:08:31 -0700 (PDT)
    X-Received: 201.202.203.204 with SMTP id abcdefg.12.123456;
            Fri, 01 Apr 2016 11:08:31 -0700 (PDT)
    DKIM-Signature: v=1; a=rsa-sha256; c=relaxed/relaxed;
            d=example.com; s=20160922;
            h=mime-version:in-reply-to:references:date:message-id:subject:from:to;
            bh=ABCDEFGHABCDEFGHABCDEFGHABCDEFGHABCDEFGHABC=;
            b=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890+/
             abcd==
    Return-Path: <dude@example.com>
    To: Test User <user@example.com>, Other User <other@example.com>
    CC: The Dude <dude@example.com>, Batman <batman@example.com>
    From: Me <me@example.com>
    Content-Type: text/plain
    Date: Fri, 1 Jan 2016 00:00:00 +0000

    Test
    """
    |> String.replace("\n", "\r\n")

    message = Mail.Parsers.RFC2822.parse(mail)

    assert message.headers[:delivered_to] == "user@example.com"
    assert message.headers[:received] == ["by 101.102.103.104 with SMTP id abcdefg", date: {{2016, 4, 1}, {11, 8, 31}}]
    assert message.headers[:x_received] == "201.202.203.204 with SMTP id abcdefg.12.123456;\r\n        Fri, 01 Apr 2016 11:08:31 -0700 (PDT)"
    assert message.headers[:dkim_signature] == "v=1; a=rsa-sha256; c=relaxed/relaxed;\r\n        d=example.com; s=20160922;\r\n        h=mime-version:in-reply-to:references:date:message-id:subject:from:to;\r\n        bh=ABCDEFGHABCDEFGHABCDEFGHABCDEFGHABCDEFGHABC=;\r\n        b=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890+/\r\n         abcd=="
  end

  test "parses with a '=' in boundary" do
    mail = """
    To: Test User <user@example.com>, Other User <other@example.com>
    CC: The Dude <dude@example.com>, Batman <batman@example.com>
    From: Me <me@example.com>
    Date: Fri, 1 Jan 2016 00:00:00 +0000
    Content-Type: multipart/mixed;
    	boundary="----=_Part_295474_20544590.1456382229928"

    Content-Type: multipart/alternative; boundary="foobar"

    ------=_Part_295474_20544590.1456382229928
    Content-Type: text/plain

    This is some text

    ------=_Part_295474_20544590.1456382229928
    Content-Type: text/html

    <h1>This is some HTML</h1>
    ------=_Part_295474_20544590.1456382229928--
    """
    |> String.replace("\n", "\r\n")

    message = Mail.Parsers.RFC2822.parse(mail)

    assert message.headers[:content_type] == ["multipart/mixed", boundary: "----=_Part_295474_20544590.1456382229928"]
  end

  test "parse long, wrapped header" do
    mail = """
    X-ReallyLongHeaderNameThatCausesBodyToWrap:
    \tBodyOnNewLine

    Body
    """
    |> String.replace("\n", "\r\n")

    message = Mail.Parsers.RFC2822.parse(mail)

    assert message.headers[:x_reallylongheadernamethatcausesbodytowrap] == "BodyOnNewLine"
  end
end
