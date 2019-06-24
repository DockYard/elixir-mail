defmodule Mail.Parsers.RFC2822Test do
  use ExUnit.Case, async: true

  test "parses a singlepart message" do
    message =
      parse_email("""
      To: user@example.com
      From: me@example.com
      Reply-To: otherme@example.com
      Subject: Test Email
      Content-Type: text/plain; foo=bar;
        baz=qux;

      This is the body!
      It has more than one line
      """)

    assert message.headers["to"] == ["user@example.com"]
    assert message.headers["from"] == "me@example.com"
    assert message.headers["reply-to"] == "otherme@example.com"
    assert message.headers["subject"] == "Test Email"
    assert message.headers["content-type"] == ["text/plain", {"foo", "bar"}, {"baz", "qux"}]
    assert message.body == "This is the body!\r\nIt has more than one line"
  end

  test "parses a multipart message" do
    message =
      parse_email("""
      To: Test User <user@example.com>, Other User <other@example.com>
      CC: The Dude <dude@example.com>, Batman <batman@example.com>
      From: Me <me@example.com>
      Reply-To: OtherMe <otherme@example.com>
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
      """)

    assert message.headers["to"] == [
             {"Test User", "user@example.com"},
             {"Other User", "other@example.com"}
           ]

    assert message.headers["cc"] == [
             {"The Dude", "dude@example.com"},
             {"Batman", "batman@example.com"}
           ]

    assert message.headers["from"] == {"Me", "me@example.com"}
    assert message.headers["reply-to"] == {"OtherMe", "otherme@example.com"}
    assert message.headers["content-type"] == ["multipart/alternative", {"boundary", "foobar"}]

    [text_part, html_part] = message.parts

    assert text_part.headers["content-type"] == "text/plain"
    assert text_part.body == "This is some text"

    assert html_part.headers["content-type"] == "text/html"
    assert html_part.body == "<h1>This is some HTML</h1>"
  end

  test "parses a multipart message with a body" do
    message =
      parse_email("""
      To: Test User <user@example.com>, Other User <other@example.com>
      CC: The Dude <dude@example.com>, Batman <batman@example.com>
      From: Me <me@example.com>
      Subject: Test email
      Mime-Version: 1.0
      Content-Type: multipart/alternative; boundary=foobar

      This is a multi-part message in MIME format
      --foobar
      Content-Type: text/plain

      This is some text

      --foobar
      Content-Type: text/html

      <h1>This is some HTML</h1>
      --foobar--
      """)

    assert message.body == nil

    [text_part, html_part] = message.parts

    assert text_part.headers["content-type"] == "text/plain"
    assert text_part.body == "This is some text"

    assert html_part.headers["content-type"] == "text/html"
    assert html_part.body == "<h1>This is some HTML</h1>"
  end

  test "erl_from_timestamp\1" do
    import Mail.Parsers.RFC2822, only: [erl_from_timestamp: 1]

    assert erl_from_timestamp("Fri, 1 Jan 2016 00:00:00 +0000") == {{2016, 1, 1}, {0, 0, 0}}
    assert erl_from_timestamp("1 Feb 2016 01:02:03 +0000") == {{2016, 2, 1}, {1, 2, 3}}
    assert erl_from_timestamp(" 1 Mar 2016 11:12:13 +0000") == {{2016, 3, 1}, {11, 12, 13}}
    assert erl_from_timestamp("\t1 Apr 2016 22:33:44 +0000") == {{2016, 4, 1}, {22, 33, 44}}
    assert erl_from_timestamp("12 Jan 2016 00:00:00 +0000") == {{2016, 1, 12}, {0, 0, 0}}
    assert erl_from_timestamp("25 Dec 2016 00:00:00 +0000 (UTC)") == {{2016, 12, 25}, {0, 0, 0}}
    assert erl_from_timestamp("03 Apr 2017 12:30:55 GMT") == {{2017, 4, 3}, {12, 30, 55}}
    # The spec specifies that the seconds are optional
    assert erl_from_timestamp("14 Jun 2019 11:24 +0000") == {{2019, 6, 14}, {11, 24, 0}}
  end

  test "erl_from_timestamp\1 with invalid RFC2822 timestamps (found in the wild)" do
    import Mail.Parsers.RFC2822, only: [erl_from_timestamp: 1]

    assert erl_from_timestamp("Thu, 16 May 2019 5:50:53 +0700") == {{2019, 5, 16}, {5, 50, 53}}
  end

  test "parses a nested multipart message with encoded part" do
    message =
      parse_email("""
      To: Test User <user@example.com>, Other User <other@example.com>
      CC: The Dude <dude@example.com>, Batman <batman@example.com>
      From: Me <me@example.com>
      Content-Type: multipart/mixed; boundary="foobar"
      Date: Fri, 1 Jan
       2016 00:00:00 +0000

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
      """)

    assert message.headers["to"] == [
             {"Test User", "user@example.com"},
             {"Other User", "other@example.com"}
           ]

    assert message.headers["cc"] == [
             {"The Dude", "dude@example.com"},
             {"Batman", "batman@example.com"}
           ]

    assert message.headers["from"] == {"Me", "me@example.com"}
    assert message.headers["content-type"] == ["multipart/mixed", {"boundary", "foobar"}]
    assert message.headers["date"] == {{2016, 1, 1}, {0, 0, 0}}

    [alt_part, attach_part] = message.parts

    assert alt_part.headers["content-type"] == ["multipart/alternative", {"boundary", "bazqux"}]
    [text_part, html_part] = alt_part.parts

    assert text_part.headers["content-type"] == "text/plain"
    assert text_part.body == "This is some text"

    assert html_part.headers["content-type"] == "text/html"
    assert html_part.body == "<h1>This is the HTML</h1>"

    assert attach_part.headers["content-type"] == "text/markdown"
    assert attach_part.headers["content-disposition"] == ["attachment", {"filename", "README.md"}]
    assert attach_part.headers["content-transfer-encoding"] == "base64"
    assert attach_part.body == "Hello world!"
  end

  test "parses unstructured headers" do
    message =
      parse_email("""
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
      """)

    assert message.headers["delivered-to"] == "user@example.com"

    assert message.headers["received"] == [[
             "by 101.102.103.104 with SMTP id abcdefg",
             {"date", {{2016, 4, 1}, {11, 8, 31}}}
           ]]

    assert message.headers["x-received"] ==
             "201.202.203.204 with SMTP id abcdefg.12.123456;        Fri, 01 Apr 2016 11:08:31 -0700 (PDT)"

    assert message.headers["dkim-signature"] ==
             "v=1; a=rsa-sha256; c=relaxed/relaxed;        d=example.com; s=20160922;        h=mime-version:in-reply-to:references:date:message-id:subject:from:to;        bh=ABCDEFGHABCDEFGHABCDEFGHABCDEFGHABCDEFGHABC=;        b=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890+/         abcd=="
  end

  test "parses more than 1 'Received:' header" do
    message =
      parse_email("""
      Received: from mail3.example.tld ([10.20.30.40]) by mail.fake.tld ([10.10.10.10]);
              Fri, 1 Apr 2016 11:09:07 -0700 (PDT)
      Received: from mail.fake.tld ([10.10.10.10]) by localhost ([127.0.0.1]);
              Fri, 1 Apr 2016 11:08:35 -0700 (PDT)
      Received: from localhost ([127.0.0.1]) by localhost (MyMailSoftware); 
              Fri, 1 Apr 2016 11:08:31 -0700 (PDT)
      To: user@example.com
      From: me@example.com
      Subject: Test Email
      Content-Type: text/plain

      Test
      """)

      assert message.headers["received"] == [
        [
          "from localhost ([127.0.0.1]) by localhost (MyMailSoftware)",
          {"date", {{2016, 4, 1}, {11, 8, 31}}}
        ],
        [
          "from mail.fake.tld ([10.10.10.10]) by localhost ([127.0.0.1])",
          {"date", {{2016, 4, 1}, {11, 8, 35}}}
        ],
        [
          "from mail3.example.tld ([10.20.30.40]) by mail.fake.tld ([10.10.10.10])",
          {"date", {{2016, 4, 1}, {11, 9, 7}}}
        ],
      ]

  end

  test "parses with a '=' in boundary" do
    message =
      parse_email("""
      To: Test User <user@example.com>, Other User <other@example.com>
      CC: The Dude <dude@example.com>, Batman <batman@example.com>
      From: Me <me@example.com>
      Date: Fri, 1 Jan 2016 00:00:00 +0000
      Content-Type: multipart/mixed;
      	boundary="----=_Part_295474_20544590.1456382229928"

      ------=_Part_295474_20544590.1456382229928
      Content-Type: text/plain

      This is some text

      ------=_Part_295474_20544590.1456382229928
      Content-Type: text/html

      <h1>This is some HTML</h1>
      ------=_Part_295474_20544590.1456382229928--
      """)

    assert message.headers["content-type"] == [
             "multipart/mixed",
             {"boundary", "----=_Part_295474_20544590.1456382229928"}
           ]
  end

  test "parse long, wrapped header" do
    message =
      parse_email("""
      X-ReallyLongHeaderNameThatCausesBodyToWrap:
      \tBodyOnNewLine

      Body
      """)

    assert message.headers["x-reallylongheadernamethatcausesbodytowrap"] == "BodyOnNewLine"
  end

  test "allow empty body (RFC2822 §3.5)" do
    message =
      parse_email("""
      To: Test User <user@example.com>
      From: Me <me@example.com>
      Date: Fri, 1 Jan 2016 00:00:00 +0000
      Subject: Blank body

      """)

    assert message.body == ""
  end

  test "address comment parsing" do
    message =
      parse_email("""
      To: Test User <user@example.com> (comment)
      CC: other@example.com (comment)
      From: <me@example.com>
      Date: Fri, 1 Jan 2016 00:00:00 +0000
      Subject: Blank body

      """)

    assert message.headers["to"] == [{"Test User", "user@example.com"}]
    assert message.headers["cc"] == ["other@example.com"]
    assert message.headers["from"] == "me@example.com"
  end

  test "address name contains comma" do
    message =
      parse_email("""
      To: "User, Test" <user@example.com>
      CC: "User, First" <first@example.com>, "User, Second" <second@example.com>, third@example.com
      From: "Lastname, First Names" <me@example.com>
      Date: Fri, 1 Jan 2016 00:00:00 +0000
      Subject: Blank body

      """)

    assert message.headers["to"] == [{"User, Test", "user@example.com"}]

    assert message.headers["cc"] == [
             {"User, First", "first@example.com"},
             {"User, Second", "second@example.com"},
             "third@example.com"
           ]

    assert message.headers["from"] == {"Lastname, First Names", "me@example.com"}
  end

  # See https://tools.ietf.org/html/rfc2047
  test "parses headers with encoded word syntax" do
    message =
      parse_email("""
      To: user@example.com
      From: me@example.com
      Subject: =?utf-8?Q?=C2=A3?=200.00 =?UTF-8?q?=F0=9F=92=B5?=
      Content-Type: multipart/mixed;
      	boundary="----=_Part_295474_20544590.1456382229928"

      ------=_Part_295474_20544590.1456382229928
      Content-Type: text/plain

      This is some text

      ------=_Part_295474_20544590.1456382229928
      Content-Type: image/png
      Content-Disposition: attachment; filename=Emoji =?utf-8?B?8J+YgA==?= Filename.png

      iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==
      ------=_Part_295474_20544590.1456382229928--
      """)

    assert message.headers["subject"] == "£200.00 💵"
    [_, part] = message.parts

    assert ["attachment", {"filename", "Emoji 😀 Filename.png"}] =
             part.headers["content-disposition"]
  end

  test "parses structured header with extraneous semicolon" do
    message =
      parse_email("""
      To: user@example.com
      From: me@example.com
      Subject: Test
      Content-Type: text/plain;
        charset=utf-8;

      This is some text
      """)

    assert message.body == "This is some text"
  end

  test "parse invalid Received header" do
    message =
      parse_email("""
      Received: by 2002:a81:578e:0:0:0:0:0 with SMTP id l136csp2273163ywb;
        Sat, 22 Jun 2019 17:59:49 -0700 (PDT)
      Received: by filter0419p1iad2.sendgrid.net with SMTP id filter0419p1iad2-17662-5D0ECF02-32
        2019-06-23 00:59:46.828888551 +0000 UTC m=+266323.963383415
      To: user@example.com
      From: me@example.com
      Subject: Test

      Body
      """)

    assert message.headers["received"] == [
      ["by filter0419p1iad2.sendgrid.net with SMTP id filter0419p1iad2-17662-5D0ECF02-32  2019-06-23 00:59:46.828888551 +0000 UTC m=+266323.963383415"],
      ["by 2002:a81:578e:0:0:0:0:0 with SMTP id l136csp2273163ywb", {"date", {{2019, 6, 22}, {17, 59, 49}}}]
    ]
  end

  defp parse_email(email),
    do: email |> convert_crlf |> Mail.Parsers.RFC2822.parse()

  def convert_crlf(text),
    do: text |> String.replace("\n", "\r\n")
end
