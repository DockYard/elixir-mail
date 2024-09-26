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

  test "parses a singlepart message with no body" do
    message =
      parse_email("""
      To: user@example.com
      From: me@example.com
      Reply-To: otherme@example.com
      Subject: Test Email
      """)

    assert message.headers["to"] == ["user@example.com"]
    assert message.headers["from"] == "me@example.com"
    assert message.headers["reply-to"] == "otherme@example.com"
    assert message.headers["subject"] == "Test Email"
    assert message.body == nil
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

    assert text_part.headers["content-type"] == ["text/plain", {"charset", "us-ascii"}]
    assert text_part.body == "This is some text"

    assert html_part.headers["content-type"] == ["text/html", {"charset", "us-ascii"}]
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

      --foobar
      x-my-header: no body!

      --foobar--
      """)

    assert message.body == nil

    [text_part, html_part, headers_only_part] = message.parts

    assert text_part.headers["content-type"] == ["text/plain", {"charset", "us-ascii"}]
    assert text_part.body == "This is some text"

    assert html_part.headers["content-type"] == ["text/html", {"charset", "us-ascii"}]
    assert html_part.body == "<h1>This is some HTML</h1>"

    assert headers_only_part.headers["x-my-header"] == "no body!"
    assert headers_only_part.body == nil
  end

  # A reproduction of an email found in the wild.
  test "parses a multipart message with a body with two html parts" do
    message =
      parse_email("""
      To: Test User <user@example.com>, Other User <other@example.com>
      CC: The Dude <dude@example.com>, Batman <batman@example.com>
      From: Me <me@example.com>
      Subject: Test email
      Mime-Version: 1.0
      Content-Type: multipart/alternative; boundary=Apple-Mail-358A6BE7-EE99-47E3-B9DE-7575E1C181D1
      Content-Transfer-Encoding: 7bit

      --Apple-Mail-358A6BE7-EE99-47E3-B9DE-7575E1C181D1
      Content-Type: text/plain; charset=utf-8
      Content-Transfer-Encoding: quoted-printable

      Text part
      --Apple-Mail-358A6BE7-EE99-47E3-B9DE-7575E1C181D1
      Content-Type: multipart/mixed;
        boundary=Apple-Mail-3B120747-147B-46E8-B375-DE9974BB35B1
      Content-Transfer-Encoding: 7bit

      --Apple-Mail-3B120747-147B-46E8-B375-DE9974BB35B1
      Content-Type: text/html; charset=us-ascii
      Content-Transfer-Encoding: 7bit

      <html></html>
      --Apple-Mail-3B120747-147B-46E8-B375-DE9974BB35B1
      Content-Type: application/pdf; name=Payment.pdf; x-apple-part-url=45B14A08-AD6D-4298-9E0D-D71498E7112E
      Content-Disposition: inline; filename=Payment.pdf
      Content-Transfer-Encoding: base64

      JVBERi0xLjcKJeLjz9MKNiAwIG9iago8PCAvQ3JlYXRvciAoT3BlblRleHQgRXhzdHJlYW0gVmVy
      --Apple-Mail-3B120747-147B-46E8-B375-DE9974BB35B1
      Content-Type: text/html; charset=utf-8
      Content-Transfer-Encoding: quoted-printable

      <html>Non empty part</html>
      --Apple-Mail-3B120747-147B-46E8-B375-DE9974BB35B1--

      --Apple-Mail-358A6BE7-EE99-47E3-B9DE-7575E1C181D1--
      """)

    assert message.body == nil

    [text_part, html_part] = message.parts

    assert text_part.headers["content-type"] == ["text/plain", {"charset", "utf-8"}]
    assert text_part.body == "Text part"

    assert html_part.headers["content-type"] == [
             "multipart/mixed",
             {"boundary", "Apple-Mail-3B120747-147B-46E8-B375-DE9974BB35B1"}
           ]

    [html_part, _pdf_part, html_part2] = html_part.parts

    assert html_part.headers["content-type"] == ["text/html", {"charset", "us-ascii"}]
    assert html_part.body == "<html></html>"

    assert html_part2.body == "<html>Non empty part</html>"

    assert Mail.get_html(message) == html_part2
  end

  test "to_datetime/1" do
    import Mail.Parsers.RFC2822, only: [to_datetime: 1]

    assert to_datetime("Fri, 1 Jan 2016 00:00:00 +0000") == ~U"2016-01-01 00:00:00Z"
    assert to_datetime("1 Feb 2016 01:02:03 +0000") == ~U"2016-02-01 01:02:03Z"
    assert to_datetime(" 1 Mar 2016 11:12:13 +0000") == ~U"2016-03-01 11:12:13Z"
    assert to_datetime("\t1 Apr 2016 22:33:44 +0000") == ~U"2016-04-01 22:33:44Z"
    assert to_datetime("12 Jan 2016 00:00:00 +0000") == ~U"2016-01-12 00:00:00Z"
    assert to_datetime("25 Dec 2016 00:00:00 +0000 (UTC)") == ~U"2016-12-25 00:00:00Z"
    # The spec specifies that the seconds are optional
    assert to_datetime("14 Jun 2019 11:24 +0000") == ~U"2019-06-14 11:24:00Z"
    assert to_datetime("28 JUN 2021 09:10 +0200") == ~U"2021-06-28 07:10:00Z"
    assert to_datetime("12 May 2020 12:08:24 UT") == ~U"2020-05-12 12:08:24Z"
  end

  # Handle obsolute date time https://datatracker.ietf.org/doc/html/rfc2822#section-4.3
  test "to_datetime/1 with obsolete information" do
    import Mail.Parsers.RFC2822, only: [to_datetime: 1]

    # Two-digit year
    assert to_datetime("12 May 50 12:08:24 +0000") == ~U"1950-05-12 12:08:24Z"
    assert to_datetime("12 May 49 12:08:24 +0000") == ~U"2049-05-12 12:08:24Z"

    # Digit month
    assert to_datetime("01 08 2023 08:59:03 +0000") == ~U"2023-08-01 08:59:03Z"

    # Obsolete time zones
    assert to_datetime("01 Aug 2023 08:59:03 UT") == ~U"2023-08-01 08:59:03Z"
    assert to_datetime("03 Apr 2017 12:30:55 UTC") == ~U"2017-04-03 12:30:55Z"
    assert to_datetime("01 Aug 2023 08:59:03 GMT") == ~U"2023-08-01 08:59:03Z"
    assert to_datetime("01 Aug 2023 08:59:03 EDT") == ~U"2023-08-01 12:59:03Z"
    assert to_datetime("01 Aug 2023 08:59:03 EST") == ~U"2023-08-01 13:59:03Z"
    assert to_datetime("01 Aug 2023 08:59:03 CDT") == ~U"2023-08-01 13:59:03Z"
    assert to_datetime("01 Aug 2023 08:59:03 CST") == ~U"2023-08-01 14:59:03Z"
    assert to_datetime("01 Aug 2023 08:59:03 MDT") == ~U"2023-08-01 14:59:03Z"
    assert to_datetime("01 Aug 2023 08:59:03 MST") == ~U"2023-08-01 15:59:03Z"
    assert to_datetime("01 Aug 2023 08:59:03 PDT") == ~U"2023-08-01 15:59:03Z"
    assert to_datetime("01 Aug 2023 08:59:03 PST") == ~U"2023-08-01 16:59:03Z"

    assert to_datetime("01 Aug 2023 08:59:03 A") == ~U"2023-08-01 08:59:03Z"
    assert to_datetime("01 Aug 2023 08:59:03 B") == ~U"2023-08-01 08:59:03Z"
    assert to_datetime("01 Aug 2023 08:59:03 C") == ~U"2023-08-01 08:59:03Z"
    assert to_datetime("01 Aug 2023 08:59:03 D") == ~U"2023-08-01 08:59:03Z"
    assert to_datetime("01 Aug 2023 08:59:03 E") == ~U"2023-08-01 08:59:03Z"
    assert to_datetime("01 Aug 2023 08:59:03 F") == ~U"2023-08-01 08:59:03Z"
    assert to_datetime("01 Aug 2023 08:59:03 G") == ~U"2023-08-01 08:59:03Z"
    assert to_datetime("01 Aug 2023 08:59:03 H") == ~U"2023-08-01 08:59:03Z"
    assert to_datetime("01 Aug 2023 08:59:03 I") == ~U"2023-08-01 08:59:03Z"
    assert to_datetime("01 Aug 2023 08:59:03 K") == ~U"2023-08-01 08:59:03Z"
    assert to_datetime("01 Aug 2023 08:59:03 Z") == ~U"2023-08-01 08:59:03Z"
  end

  test "to_datetime/1 with invalid RFC2822 timestamps (found in the wild)" do
    import Mail.Parsers.RFC2822, only: [to_datetime: 1]

    assert to_datetime("Thu, 16 May 2019 5:50:53 +0700") == ~U"2019-05-15 22:50:53Z"
    assert to_datetime("Tue May 30 15:29:15 2017") == ~U"2017-05-30 15:29:15Z"
    assert to_datetime("Tue May 3 15:29:15 2017") == ~U"2017-05-03 15:29:15Z"
    assert to_datetime("Wed, 14 05 2015 12:34:17") == ~U"2015-05-14 12:34:17Z"
    assert to_datetime("Tue, 20 Jun 2017 09:44:58.568 +0000 (UTC)") == ~U"2017-06-20 09:44:58Z"
    assert to_datetime("Fri Apr 15 17:22:55 CAT 2016") == ~U"2016-04-15 17:22:55Z"

    [
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December"
    ]
    |> Enum.with_index(1)
    |> Enum.each(fn {long_month, idx} ->
      idx =
        if idx < 10 do
          "0#{idx}"
        else
          idx
        end

      {:ok, datetime, 0} = DateTime.from_iso8601("2024-#{idx}-13 18:29:58Z")
      assert to_datetime("13 #{long_month} 2024 18:29:58 +0000") == datetime
    end)
  end

  test "parse_recipient_value retrieves a list of name and addresses" do
    recipient =
      "The Dude <dude@example.com>, batman@example.com, super<compact@recipi.ent>, \"an@email.com\" <an@email.com>"

    retrieved_recipients = [
      {"The Dude", "dude@example.com"},
      "batman@example.com",
      {"super", "compact@recipi.ent"},
      {"an@email.com", "an@email.com"}
    ]

    assert parse_recipient(recipient) == retrieved_recipients
  end

  test "parse_recipient_value retrieves an empty list when recipient is empty" do
    assert parse_recipient("") == []
  end

  test "parse_recipient_value retrieves an empty list when no \"address\" found" do
    assert parse_recipient("NoEmail") == []
  end

  test "parse_recipient_value retrieves a list when only one \"address\" found" do
    assert parse_recipient("dude@example.com") == ["dude@example.com"]
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
    assert message.headers["date"] == ~U"2016-01-01 00:00:00Z"

    [alt_part, attach_part] = message.parts

    assert alt_part.headers["content-type"] == ["multipart/alternative", {"boundary", "bazqux"}]
    [text_part, html_part] = alt_part.parts

    assert text_part.headers["content-type"] == ["text/plain", {"charset", "us-ascii"}]
    assert text_part.body == "This is some text"

    assert html_part.headers["content-type"] == ["text/html", {"charset", "us-ascii"}]
    assert html_part.body == "<h1>This is the HTML</h1>"

    assert attach_part.headers["content-type"] == ["text/markdown", {"charset", "us-ascii"}]
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

    assert message.headers["received"] == [
             [
               "by 101.102.103.104 with SMTP id abcdefg",
               {"date", ~U"2016-04-01 18:08:31Z"}
             ]
           ]

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
               {"date", ~U"2016-04-01 18:08:31Z"}
             ],
             [
               "from mail.fake.tld ([10.10.10.10]) by localhost ([127.0.0.1])",
               {"date", ~U"2016-04-01 18:08:35Z"}
             ],
             [
               "from mail3.example.tld ([10.20.30.40]) by mail.fake.tld ([10.10.10.10])",
               {"date", ~U"2016-04-01 18:09:07Z"}
             ]
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
      Subject: =?utf-8?Q?=C2=A3?=200.00=?UTF-8?q?_=F0=9F=92=B5?=
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

  test "parses headers with non-encoded string that looks like encoded word syntax" do
    message =
      parse_email("""
      To: user@example.com
      From: me@example.com
      Subject: Subject that has =? for an unknown reason with =?utf-8?B?8J+YgA==?=
      List-Unsubscribe: https://some-domain.com/te/c/abcdef=?signature=abcdef
      Content-Type: multipart/mixed;
      	boundary="----=_Part_295474_20544590.1456382229928"

      ------=_Part_295474_20544590.1456382229928
      Content-Type: text/plain

      This is some text

      ------=_Part_295474_20544590.1456382229928--
      """)

    assert message.headers["subject"] == "Subject that has =? for an unknown reason with 😀"

    assert message.headers["list-unsubscribe"] ==
             "https://some-domain.com/te/c/abcdef=?signature=abcdef"
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
             [
               "by filter0419p1iad2.sendgrid.net with SMTP id filter0419p1iad2-17662-5D0ECF02-32  2019-06-23 00:59:46.828888551 +0000 UTC m=+266323.963383415"
             ],
             [
               "by 2002:a81:578e:0:0:0:0:0 with SMTP id l136csp2273163ywb",
               {"date", ~U"2019-06-23 00:59:49Z"}
             ]
           ]
  end

  test "parse received header with wrapped date" do
    message =
      parse_email("""
      Received: from EUR01-HE1-obe.outbound.protection.outlook.com
               (213.199.154.213) by us1.smtp.exclaimer.net (191.237.4.149) with Exclaimer
               Signature Manager ESMTP Proxy us1.smtp.exclaimer.net; Wed, 1 Aug 2018
               09:49:43 +0000
      Received: from EUR01-HE1-obe.outbound.protection.outlook.com
      	 (213.199.154.208) by us1.smtp.exclaimer.net (191.237.4.149) with Exclaimer
      	 Signature Manager ESMTP Proxy us1.smtp.exclaimer.net; Mon, 6 Aug 2018
      	 07:23:18 +0000
      """)

    assert message.headers["received"] == [
             [
               "from EUR01-HE1-obe.outbound.protection.outlook.com\t (213.199.154.208) by us1.smtp.exclaimer.net (191.237.4.149) with Exclaimer\t Signature Manager ESMTP Proxy us1.smtp.exclaimer.net",
               {"date", ~U"2018-08-06 07:23:18Z"}
             ],
             [
               "from EUR01-HE1-obe.outbound.protection.outlook.com         (213.199.154.213) by us1.smtp.exclaimer.net (191.237.4.149) with Exclaimer         Signature Manager ESMTP Proxy us1.smtp.exclaimer.net",
               {"date", ~U"2018-08-01 09:49:43Z"}
             ]
           ]
  end

  test "parse invalid date in Received header" do
    message =
      parse_email("""
      Received: from local-ip[x.x.x.x] by FTGS; 28-Dec-2014 20:04:31 +0200
      Received: from trusted client by mx4.sika.com; Tue May 30 15:29:15 2017
      Received: from freshdesk.com (ec2-x-x-x-x.compute-1.amazonaws.com [x.x.x.x])
      	by x.sendgrid.net (SG) with ESMTP id eSJywaprRzabHWQplQP8xw
      	for <x@example.com>; Tue, 20 Jun 2017 09:44:58.568 +0000 (UTC)
      Received: from ip<x.x.x.> ([x.x.x.x])
      	by zm-as2 with ESMTP id fd672312-a36d-4bfe-8770-01b5cb3baca4 for nla2@archstl.org;
      	Tue Aug  8 12:05:31 2017
      Received: from junghyuk@gbtp.or.kr with  Spamsniper 2.96.32 (Processed in 1.059114 secs);
      Received: from x.x.x.x
      	by Spam Quarantine V01-06377SMG01.x.x.x (x.x.x.x) for <x@example.com>; Fri Apr 15 17:22:55 CAT 2016
      Received: from w.x.y.z ([1.1.1.1]) by x.y.local with InterScan Messaging Security Suite; Mon, 25 Nov 2019\u0020\r\n\t13:00:46 +0200
      """)

    assert message.headers["received"] == [
             [
               "from w.x.y.z ([1.1.1.1]) by x.y.local with InterScan Messaging Security Suite",
               {"date", ~U"2019-11-25 11:00:46Z"}
             ],
             [
               "from x.x.x.x\tby Spam Quarantine V01-06377SMG01.x.x.x (x.x.x.x) for <x@example.com>",
               {"date", ~U"2016-04-15 17:22:55Z"}
             ],
             ["from junghyuk@gbtp.or.kr with  Spamsniper 2.96.32 (Processed in 1.059114 secs)"],
             [
               "from ip<x.x.x.> ([x.x.x.x])\tby zm-as2 with ESMTP id fd672312-a36d-4bfe-8770-01b5cb3baca4 for nla2@archstl.org",
               {"date", ~U"2017-08-08 12:05:31Z"}
             ],
             [
               "from freshdesk.com (ec2-x-x-x-x.compute-1.amazonaws.com [x.x.x.x])\tby x.sendgrid.net (SG) with ESMTP id eSJywaprRzabHWQplQP8xw\tfor <x@example.com>",
               {"date", ~U"2017-06-20 09:44:58Z"}
             ],
             ["from trusted client by mx4.sika.com", {"date", ~U"2017-05-30 15:29:15Z"}],
             ["from local-ip[x.x.x.x] by FTGS", {"date", ~U"2014-12-28 18:04:31Z"}]
           ]
  end

  test "parse date in date header" do
    message =
      parse_email("""
      Date: Wed, 14 05 2015 12:34:17
      """)

    assert message.headers["date"] == ~U"2015-05-14 12:34:17Z"
  end

  test "handle comment after semi-colon in received header value" do
    message =
      parse_email("""
      Received: from smtp.notes.na.collabserv.com (192.155.248.91)
      	by d50lp03.ny.us.ibm.com (158.87.18.22) with IBM ESMTP SMTP Gateway: Authorized Use Only! Violators will be prosecuted;
      	(version=TLSv1/SSLv3 cipher=AES128-GCM-SHA256 bits=128/128)
      	Thu, 8 Jun 2017 04:22:53 -0400
      """)

    assert message.headers["received"] == [
             [
               "from smtp.notes.na.collabserv.com (192.155.248.91)\tby d50lp03.ny.us.ibm.com (158.87.18.22) with IBM ESMTP SMTP Gateway: Authorized Use Only! Violators will be prosecuted (version=TLSv1/SSLv3 cipher=AES128-GCM-SHA256 bits=128/128)",
               {"date", ~U"2017-06-08 08:22:53Z"}
             ]
           ]
  end

  test "parses quoted string filename with embedded semi-colon (RFC2822 §3.2.5)" do
    message =
      parse_email("""
      To: user@example.com
      From: me@example.com
      Subject: Test
      Content-Type: multipart/mixed;
      	boundary="----=_Part_295474_20544590.1456382229928"

      ------=_Part_295474_20544590.1456382229928
      Content-Type: text/plain

      This is some text

      ------=_Part_295474_20544590.1456382229928
      Content-Type: image/gif;
       charset="UTF-8";
       name="&#9733;.gif"
      Content-Transfer-Encoding: base64
      Content-Disposition: inline;
       filename="&#9733;.gif"
      Content-Id: <5cf3f485fe9b1d93040fac887e133234.gif>
      X-Attachment-Id: <5cf3f485fe9b1d93040fac887e133234.gif>

      R0lGODlhOw==\r\n"
      ------=_Part_295474_20544590.1456382229928--
      """)

    [_, part] = message.parts
    assert ["inline", {"filename", "&#9733;.gif"}] = part.headers["content-disposition"]

    assert ["image/gif", {"charset", "UTF-8"}, {"name", "&#9733;.gif"}] =
             part.headers["content-type"]
  end

  test "content-type mixed with no body" do
    message =
      parse_email("""
      To: user@example.com
      From: me@example.com
      Subject: Test
      Content-Type: multipart/mixed;
      	boundary="----=_Part_295474_20544590.1456382229928"

      """)

    assert message.parts == []
    assert message.body == nil
  end

  test "content-type with explicit charset" do
    message =
      parse_email("""
      Content-Type: text/html; charset=us-ascii
      """)

    assert message.headers["content-type"] == ["text/html", {"charset", "us-ascii"}]
  end

  test "content-type with atypical casing" do
    message =
      parse_email("""
      Content-type: text/html; charset=us-ascii
      """)

    assert message.headers["content-type"] == ["text/html", {"charset", "us-ascii"}]
  end

  test "content-type with implicit charset" do
    message =
      parse_email("""
      Content-Type: text/html
      """)

    assert message.headers["content-type"] == ["text/html", {"charset", "us-ascii"}]
  end

  defp parse_email(email),
    do: email |> convert_crlf |> Mail.Parsers.RFC2822.parse()

  defp parse_recipient(recipient),
    do: Mail.Parsers.RFC2822.parse_recipient_value(recipient)

  def convert_crlf(text),
    do: text |> String.replace("\n", "\r\n")
end
