defmodule Mail.Renderers.RFC2822Test do
  use ExUnit.Case, async: true
  import Mail.Assertions.RFC2822

  # from https://github.com/mathiasbynens/small/blob/master/jpeg.jpg
  @tiny_jpeg_binary <<255, 216, 255, 219, 0, 67, 0, 3, 2, 2, 2, 2, 2, 3, 2, 2, 2, 3, 3, 3, 3, 4,
                      6, 4, 4, 4, 4, 4, 8, 6, 6, 5, 6, 9, 8, 10, 10, 9, 8, 9, 9, 10, 12, 15, 12,
                      10, 11, 14, 11, 9, 9, 13, 17, 13, 14, 15, 16, 16, 17, 16, 10, 12, 18, 19,
                      18, 16, 19, 15, 16, 16, 16, 255, 201, 0, 11, 8, 0, 1, 0, 1, 1, 1, 17, 0,
                      255, 204, 0, 6, 0, 16, 16, 5, 255, 218, 0, 8, 1, 1, 0, 0, 63, 0, 210, 207,
                      32, 255, 217>>

  test "header - capitalizes and hyphenates keys, joins lists according to spec" do
    header = Mail.Renderers.RFC2822.render_header("foo_bar", ["abcd", baz_buzz: "qux"])
    assert header == "Foo-Bar: abcd; baz-buzz=qux"
  end

  test "quotes header parameters if necessary" do
    header =
      Mail.Renderers.RFC2822.render_header("Content-Disposition", [
        "attachment",
        filename: "my-test-file"
      ])

    assert header == "Content-Disposition: attachment; filename=my-test-file"

    header =
      Mail.Renderers.RFC2822.render_header("Content-Disposition", [
        "attachment",
        filename: "my test file"
      ])

    assert header == "Content-Disposition: attachment; filename=\"my test file\""

    header =
      Mail.Renderers.RFC2822.render_header("Content-Disposition", [
        "attachment",
        filename: "my;test;file"
      ])

    assert header == "Content-Disposition: attachment; filename=\"my;test;file\""
  end

  test "encodes header if necessary" do
    assert Mail.Renderers.RFC2822.render_header("Subject", [
             "Hello World!"
           ]) == "Subject: Hello World!"

    assert Mail.Renderers.RFC2822.render_header("Subject", [
             String.duplicate("a", 73)
           ]) == "Subject: #{String.duplicate("a", 73)}"

    assert Mail.Renderers.RFC2822.render_header("Subject", [
             "Hello World 😀"
           ]) == "Subject: =?UTF-8?Q?Hello World =F0=9F=98=80?="

    assert Mail.Renderers.RFC2822.render_header("Subject", [
             "Café résumé"
           ]) == "Subject: =?UTF-8?Q?Caf=C3=A9 r=C3=A9sum=C3=A9?="

    assert Mail.Renderers.RFC2822.render_header("Subject", [
             "Hello 世界 World"
           ]) == "Subject: =?UTF-8?Q?Hello =E4=B8=96=E7=95=8C World?="
  end

  test "address headers renders list of recipients" do
    header = Mail.Renderers.RFC2822.render_header("from", "user1@example.com")
    assert header == "From: user1@example.com"
    header = Mail.Renderers.RFC2822.render_header("to", "user1@example.com")
    assert header == "To: user1@example.com"
    header = Mail.Renderers.RFC2822.render_header("cc", "user1@example.com")
    assert header == "Cc: user1@example.com"
    header = Mail.Renderers.RFC2822.render_header("bcc", "user1@example.com")
    assert header == "Bcc: user1@example.com"

    header =
      Mail.Renderers.RFC2822.render_header("from", [
        "user1@example.com",
        {"User 2", "user2@example.com"}
      ])

    assert header == "From: user1@example.com, \"User 2\" <user2@example.com>"

    header =
      Mail.Renderers.RFC2822.render_header("to", [
        "user1@example.com",
        {"User 2", "user2@example.com"}
      ])

    assert header == "To: user1@example.com, \"User 2\" <user2@example.com>"

    header =
      Mail.Renderers.RFC2822.render_header("cc", [
        "user1@example.com",
        {"User 2", "user2@example.com"}
      ])

    assert header == "Cc: user1@example.com, \"User 2\" <user2@example.com>"

    header =
      Mail.Renderers.RFC2822.render_header("bcc", [
        "user1@example.com",
        {"User 2", "user2@example.com"}
      ])

    assert header == "Bcc: user1@example.com, \"User 2\" <user2@example.com>"
  end

  ["to", "cc", "bcc", "from", "reply-to"]
  |> Enum.each(fn header ->
    test "validate address headers (#{header})" do
      assert_raise ArgumentError, fn ->
        Mail.Renderers.RFC2822.render_header(unquote(header), {"Test User", "@example.com"})
      end

      assert_raise ArgumentError, fn ->
        Mail.Renderers.RFC2822.render_header(unquote(header), {"Test User", nil})
      end

      assert_raise ArgumentError, fn ->
        Mail.Renderers.RFC2822.render_header(unquote(header), {"Test User", ""})
      end

      assert_raise ArgumentError, fn ->
        Mail.Renderers.RFC2822.render_header(unquote(header), {"Test User", "user"})
      end

      assert_raise ArgumentError, fn ->
        Mail.Renderers.RFC2822.render_header(unquote(header), {"Test User", nil})
      end
    end
  end)

  test "content-transfer-encoding rendering hyphenates values" do
    header = Mail.Renderers.RFC2822.render_header("content_transfer_encoding", :quoted_printable)
    assert header == "Content-Transfer-Encoding: quoted-printable"
  end

  test "renders simple key / value pair header" do
    header = Mail.Renderers.RFC2822.render_header("subject", "Hello World!")
    assert header == "Subject: Hello World!"
  end

  ["Message-Id", "In-Reply-To", "References", "Resent-Message-Id", "Content-Id"]
  |> Enum.each(fn header ->
    test "does not encode #{header} header (msg-id)" do
      message_id = "<" <> String.duplicate("a", 73) <> "@example.com>"
      header = Mail.Renderers.RFC2822.render_header(unquote(header), message_id)
      assert header == "#{unquote(header)}: #{message_id}"
    end
  end)

  test "does not encode References header (msg-id) with multiple message-ids" do
    message_ids =
      1..3
      |> Enum.map(fn index -> "<id-#{index}-" <> String.duplicate("b", 70) <> "@example.com>" end)
      |> Enum.join(" ")

    header = Mail.Renderers.RFC2822.render_header("References", message_ids)

    assert header == "References: #{message_ids}"
  end

  test "headers - renders all headers" do
    headers = Mail.Renderers.RFC2822.render_headers(%{"foo" => "bar", "baz" => "qux"})
    assert headers == "Foo: bar\r\nBaz: qux"
  end

  test "headers - handles empty headers as nil" do
    headers =
      Mail.Renderers.RFC2822.render_headers(%{
        "content-type" => "text/plain",
        "message-id" => nil,
        "content-disposition" => "attachment"
      })

    assert headers == "Content-Type: text/plain\r\nContent-Disposition: attachment"
  end

  test "header - reject nil" do
    refute Mail.Renderers.RFC2822.render_header("message-id", nil)
  end

  test "headers - handles empty headers as empty list" do
    headers =
      Mail.Renderers.RFC2822.render_headers(%{
        "content-type" => "text/plain",
        "to" => [],
        "content-disposition" => "attachment"
      })

    assert headers == "Content-Type: text/plain\r\nContent-Disposition: attachment"
  end

  test "header - reject empty list" do
    refute Mail.Renderers.RFC2822.render_header("to", [])
  end

  test "headers - handles empty headers as blank string" do
    headers =
      Mail.Renderers.RFC2822.render_headers(%{
        "content-type" => "text/plain",
        "from" => "         ",
        "content-disposition" => "attachment"
      })

    assert headers == "Content-Type: text/plain\r\nContent-Disposition: attachment"
  end

  test "header - reject blank_string" do
    refute Mail.Renderers.RFC2822.render_header("from", "")
    refute Mail.Renderers.RFC2822.render_header("from", "        ")
  end

  test "headers - blacklist certain headers" do
    headers =
      Mail.Renderers.RFC2822.render_headers(%{"foo" => "bar", "baz" => "qux"}, ["foo", "baz"])

    assert headers == ""
  end

  test "headers - erl date" do
    header = Mail.Renderers.RFC2822.render_header("date", {{2016, 1, 1}, {0, 0, 0}})
    assert header == "Date: Fri, 1 Jan 2016 00:00:00 +0000"
  end

  test "headers - DateTime" do
    header = Mail.Renderers.RFC2822.render_header("date", ~U"2023-08-01 09:35:50Z")
    assert header == "Date: Tue, 1 Aug 2023 09:35:50 +0000"
  end

  test "renders each part recursively" do
    sub_part_1 = Mail.Message.build_text("Hello there! 1 + 1 = 2")
    sub_part_2 = Mail.Message.build_html(~s|<a href="/">Hello there! 1 + 1 = 2</a>|)

    part =
      Mail.build_multipart()
      |> Mail.Message.put_content_type("multipart/alternative")
      |> Mail.Message.put_boundary("foobar")
      |> Mail.Message.put_part(sub_part_1)
      |> Mail.Message.put_part(sub_part_2)

    result = Mail.Renderers.RFC2822.render_part(part) <> "\r\n"
    {:ok, fixture} = File.read("test/fixtures/recursive-part-rendering.eml")

    assert result == fixture
  end

  test "renders a plain message" do
    message =
      Mail.build()
      |> Mail.put_to("user@example.com")
      |> Mail.put_subject("Test email")
      |> Mail.put_text("Some text")

    {:ok, fixture} = File.read("test/fixtures/simple-plain-rendering.eml")

    result = Mail.Renderers.RFC2822.render(message) <> "\r\n"

    assert result == fixture
  end

  test "renders a multipart mail" do
    message =
      Mail.build_multipart()
      |> Mail.put_to("user1@example.com")
      |> Mail.put_from({"User2", "user2@example.com"})
      |> Mail.put_reply_to({"User3", "user3@example.com"})
      |> Mail.put_subject("Test email")
      |> Mail.put_text("Some text\r\n")
      |> Mail.put_html("<h1>Some HTML</h1>")
      |> Mail.Message.put_content_type("multipart/alternative")
      |> Mail.Message.put_boundary("foobar")

    {:ok, fixture} = File.read("test/fixtures/simple-multipart-rendering.eml")

    result = Mail.Renderers.RFC2822.render(message)

    assert_rfc2822_equal(result, fixture)
  end

  test "renders a multipart mail with jpeg attachment" do
    message =
      Mail.build_multipart()
      |> Mail.put_to("user1@example.com")
      |> Mail.put_from({"User2", "user2@example.com"})
      |> Mail.put_subject("Test email")
      |> Mail.put_text("Some text\r\n")
      |> Mail.put_html("<h1>Some HTML</h1>")
      |> Mail.put_attachment({"tiny_jpeg.jpg", @tiny_jpeg_binary})

    {:ok, fixture} = File.read("test/fixtures/multipart-jpeg-attachment-rendering.eml")

    result = Mail.Renderers.RFC2822.render(message)

    assert_rfc2822_equal(result, fixture)
  end

  test "renders a multipart mail consisting of an attachment only, no text parts" do
    message =
      Mail.build_multipart()
      |> Mail.put_to("user1@example.com")
      |> Mail.put_from("user2@example.com")
      |> Mail.put_subject("Test email")
      |> Mail.put_attachment({"tiny_jpeg.jpg", @tiny_jpeg_binary})

    {:ok, fixture} = File.read("test/fixtures/multipart-no-text-parts-rendering.eml")

    result = Mail.Renderers.RFC2822.render(message)

    assert_rfc2822_equal(result, fixture)
  end

  test "rendering filters out BCC" do
    message =
      Mail.build()
      |> Mail.put_bcc("user@example.com")
      |> Mail.put_text("Something")
      |> Mail.Renderers.RFC2822.render()
      |> Mail.Parsers.RFC2822.parse()

    refute Map.has_key?(message.headers, "bcc")
  end

  test "properly encodes body based upon Content-Transfer-Encoding value" do
    file = File.read!("README.md")

    message =
      Mail.build()
      |> Mail.put_text(file)
      |> Mail.Message.put_header("content_transfer_encoding", "base64")

    result = Mail.Renderers.RFC2822.render(message)

    encoded_file = Mail.Encoder.encode(file, :base64)

    assert result =~ encoded_file
  end

  test "timestamp_from_erl/1 converts to RFC2822 date and time format" do
    timestamp = Mail.Renderers.RFC2822.timestamp_from_datetime({{2016, 1, 1}, {0, 0, 0}})
    assert timestamp == "Fri, 1 Jan 2016 00:00:00 +0000"

    timestamp = Mail.Renderers.RFC2822.timestamp_from_datetime(~U"2023-08-01 09:40:46Z")
    assert timestamp == "Tue, 1 Aug 2023 09:40:46 +0000"

    # No std_offset
    timestamp =
      Mail.Renderers.RFC2822.timestamp_from_datetime(%DateTime{
        calendar: Calendar.ISO,
        day: 1,
        hour: 9,
        microsecond: {0, 0},
        minute: 40,
        month: 8,
        second: 46,
        std_offset: 0,
        time_zone: "Africa/Johannesburg",
        utc_offset: 7200,
        year: 2023,
        zone_abbr: "SAST"
      })

    assert timestamp == "Tue, 1 Aug 2023 09:40:46 +0200"

    # with std_offset
    timestamp =
      Mail.Renderers.RFC2822.timestamp_from_datetime(%DateTime{
        calendar: Calendar.ISO,
        day: 1,
        hour: 9,
        microsecond: {0, 0},
        minute: 40,
        month: 8,
        second: 46,
        std_offset: 3600,
        time_zone: "America/New_York",
        utc_offset: -18000,
        year: 2023,
        zone_abbr: "EDT"
      })

    assert timestamp == "Tue, 1 Aug 2023 09:40:46 -0400"

    # with minutes in offset
    timestamp =
      Mail.Renderers.RFC2822.timestamp_from_datetime(%DateTime{
        calendar: Calendar.ISO,
        day: 1,
        hour: 9,
        microsecond: {0, 0},
        minute: 40,
        month: 8,
        second: 46,
        std_offset: 0,
        time_zone: "Australia/Eucla",
        utc_offset: 31500,
        year: 2023,
        zone_abbr: "EDT"
      })

    assert timestamp == "Tue, 1 Aug 2023 09:40:46 +0845"
  end

  test "will raise when an invalid address in tuple with `to`" do
    assert_raise ArgumentError, fn ->
      Mail.build()
      |> Mail.put_to({"Test User", "@example.com"})
      |> Mail.Renderers.RFC2822.render()
    end
  end

  test "will raise when an invalid address with `to`" do
    assert_raise ArgumentError, fn ->
      Mail.build()
      |> Mail.put_to("@example.com")
      |> Mail.Renderers.RFC2822.render()
    end
  end

  test "will raise when an invalid address in tuple with `cc`" do
    assert_raise ArgumentError, fn ->
      Mail.build()
      |> Mail.put_cc({"Test User", "@example.com"})
      |> Mail.Renderers.RFC2822.render()
    end
  end

  test "will raise when an invalid address with `cc`" do
    assert_raise ArgumentError, fn ->
      Mail.build()
      |> Mail.put_cc("@example.com")
      |> Mail.Renderers.RFC2822.render()
    end
  end

  describe "multipart configuration" do
    # This test ensures that Mail.build_multipart() is respected even if only one part is supplied
    test "multipart/alternative with only one part and no attachments" do
      message =
        Mail.build_multipart()
        |> Mail.put_to("user1@example.com")
        |> Mail.put_from({"User2", "user2@example.com"})
        |> Mail.put_subject("Test email")
        |> Mail.put_text("Some text")
        |> Mail.Renderers.RFC2822.render()
        |> Mail.Parsers.RFC2822.parse()

      assert %Mail.Message{
               headers: %{"content-type" => ["multipart/alternative", {"boundary", _boundary}]},
               parts: [
                 %Mail.Message{
                   headers: %{"content-type" => ["text/plain", {"charset", "UTF-8"}]},
                   body: "Some text",
                   parts: [],
                   multipart: false
                 }
               ]
             } = message
    end

    test "multipart/alternative with text/plain and text/html" do
      message =
        Mail.build_multipart()
        |> Mail.put_to("user1@example.com")
        |> Mail.put_from({"User2", "user2@example.com"})
        |> Mail.put_subject("Test email")
        |> Mail.put_text("Some text")
        |> Mail.put_html("<h1>Some HTML</h1>")
        |> Mail.Renderers.RFC2822.render()
        |> Mail.Parsers.RFC2822.parse()

      assert %Mail.Message{
               headers: %{"content-type" => ["multipart/alternative", {"boundary", _boundary}]},
               parts: [
                 %Mail.Message{
                   headers: %{"content-type" => ["text/plain", {"charset", "UTF-8"}]},
                   body: "Some text",
                   parts: [],
                   multipart: false
                 },
                 %Mail.Message{
                   headers: %{"content-type" => ["text/html", {"charset", "UTF-8"}]},
                   body: "<h1>Some HTML</h1>",
                   parts: [],
                   multipart: false
                 }
               ]
             } = message
    end

    test "multipart/related with text/html and inline attachment" do
      message =
        Mail.build_multipart()
        |> Mail.put_to("user1@example.com")
        |> Mail.put_from({"User2", "user2@example.com"})
        |> Mail.put_subject("Test email")
        |> Mail.put_html("<h1>Some HTML</h1>")
        |> Mail.put_attachment({"inline_jpeg.jpg", @tiny_jpeg_binary},
          headers: %{
            content_id: "c_id",
            content_type: "image/jpeg",
            x_attachment_id: "a_id",
            content_disposition: ["inline", filename: "image.jpg"]
          }
        )
        |> Mail.Renderers.RFC2822.render()
        |> Mail.Parsers.RFC2822.parse()

      assert %Mail.Message{
               headers: %{"content-type" => ["multipart/related", {"boundary", _boundary}]},
               parts: [
                 %Mail.Message{
                   headers: %{"content-type" => ["text/html", {"charset", "UTF-8"}]}
                 },
                 %Mail.Message{
                   headers: %{
                     "content-transfer-encoding" => "base64",
                     "content-type" => ["image/jpeg", {"charset", "us-ascii"}],
                     "content-id" => "c_id",
                     "content-disposition" => ["inline", {"filename", "image.jpg"}],
                     "x-attachment-id" => "a_id"
                   }
                 }
               ]
             } = message
    end

    test "multipart/mixed with text/html and attachment" do
      message =
        Mail.build_multipart()
        |> Mail.put_to("user1@example.com")
        |> Mail.put_from({"User2", "user2@example.com"})
        |> Mail.put_subject("Test email")
        |> Mail.put_html("<h1>Some HTML</h1>")
        |> Mail.put_attachment({"image.jpg", @tiny_jpeg_binary})
        |> Mail.Renderers.RFC2822.render()
        |> Mail.Parsers.RFC2822.parse()

      assert %Mail.Message{
               headers: %{"content-type" => ["multipart/mixed", {"boundary", _boundary}]},
               parts: [
                 %Mail.Message{
                   headers: %{"content-type" => ["text/html", {"charset", "UTF-8"}]}
                 },
                 %Mail.Message{
                   headers: %{
                     "content-transfer-encoding" => "base64",
                     "content-type" => ["image/jpeg", {"charset", "us-ascii"}],
                     "content-disposition" => ["attachment", {"filename", "image.jpg"}]
                   }
                 }
               ]
             } = message
    end

    test "multipart/mixed with multipart/alternative and attachment" do
      message =
        Mail.build_multipart()
        |> Mail.put_to("user1@example.com")
        |> Mail.put_from({"User2", "user2@example.com"})
        |> Mail.put_subject("Test email")
        |> Mail.put_attachment({"tiny_jpeg.jpg", @tiny_jpeg_binary})
        |> Mail.put_text("Some text")
        |> Mail.put_html("<h1>Some HTML</h1>")
        |> Mail.Renderers.RFC2822.render()
        |> Mail.Parsers.RFC2822.parse()

      assert %Mail.Message{
               headers: %{"content-type" => ["multipart/mixed", {"boundary", _mixed_boundary}]},
               parts: [
                 %Mail.Message{
                   headers: %{
                     "content-type" => [
                       "multipart/alternative",
                       {"boundary", _alternative_boundary}
                     ]
                   },
                   parts: [
                     %Mail.Message{
                       headers: %{"content-type" => ["text/plain", {"charset", "UTF-8"}]},
                       body: "Some text",
                       parts: [],
                       multipart: false
                     },
                     %Mail.Message{
                       headers: %{"content-type" => ["text/html", {"charset", "UTF-8"}]},
                       body: "<h1>Some HTML</h1>",
                       parts: [],
                       multipart: false
                     }
                   ]
                 },
                 %Mail.Message{
                   headers: %{
                     "content-transfer-encoding" => "base64",
                     "content-type" => ["image/jpeg", {"charset", "us-ascii"}]
                   },
                   parts: [],
                   multipart: false
                 }
               ]
             } = message
    end

    test "multipart/related and inline attachment and multipart/alternative with text/plain and text/html" do
      message =
        Mail.build_multipart()
        |> Mail.put_to("user1@example.com")
        |> Mail.put_from({"User2", "user2@example.com"})
        |> Mail.put_subject("Test email")
        |> Mail.put_attachment({"inline_jpeg.jpg", @tiny_jpeg_binary},
          headers: %{
            content_id: "c_id",
            content_type: "image/jpeg",
            x_attachment_id: "a_id",
            content_disposition: ["inline", filename: "image.jpg"]
          }
        )
        |> Mail.put_text("Some text")
        |> Mail.put_html("<h1>Some HTML</h1>")
        |> Mail.Renderers.RFC2822.render()
        |> Mail.Parsers.RFC2822.parse()

      assert %Mail.Message{
               headers: %{
                 "content-type" => ["multipart/related", {"boundary", _related_boundary}]
               },
               parts: [
                 %Mail.Message{
                   headers: %{
                     "content-type" => [
                       "multipart/alternative",
                       {"boundary", _alternative_boundary}
                     ]
                   },
                   parts: [
                     %Mail.Message{
                       headers: %{"content-type" => ["text/plain", {"charset", "UTF-8"}]},
                       body: "Some text",
                       parts: [],
                       multipart: false
                     },
                     %Mail.Message{
                       headers: %{"content-type" => ["text/html", {"charset", "UTF-8"}]},
                       body: "<h1>Some HTML</h1>",
                       parts: [],
                       multipart: false
                     }
                   ]
                 },
                 %Mail.Message{
                   headers: %{
                     "content-transfer-encoding" => "base64",
                     "content-type" => ["image/jpeg", {"charset", "us-ascii"}],
                     "content-id" => "c_id",
                     "content-disposition" => ["inline", {"filename", "image.jpg"}],
                     "x-attachment-id" => "a_id"
                   },
                   parts: [],
                   multipart: false
                 }
               ]
             } = message
    end

    test "multipart/mixed with attachment and multipart/alternative with text/plain and text/html" do
      message =
        Mail.build_multipart()
        |> Mail.put_to("user1@example.com")
        |> Mail.put_from({"User2", "user2@example.com"})
        |> Mail.put_subject("Test email")
        |> Mail.put_attachment({"image.jpg", @tiny_jpeg_binary})
        |> Mail.put_text("Some text")
        |> Mail.put_html("<h1>Some HTML</h1>")
        |> Mail.Renderers.RFC2822.render()
        |> Mail.Parsers.RFC2822.parse()

      assert %Mail.Message{
               headers: %{
                 "content-type" => ["multipart/mixed", {"boundary", _mixed_boundary}]
               },
               parts: [
                 %Mail.Message{
                   headers: %{
                     "content-type" => [
                       "multipart/alternative",
                       {"boundary", _alternative_boundary}
                     ]
                   },
                   parts: [
                     %Mail.Message{
                       headers: %{"content-type" => ["text/plain", {"charset", "UTF-8"}]},
                       body: "Some text",
                       parts: [],
                       multipart: false
                     },
                     %Mail.Message{
                       headers: %{"content-type" => ["text/html", {"charset", "UTF-8"}]},
                       body: "<h1>Some HTML</h1>",
                       parts: [],
                       multipart: false
                     }
                   ]
                 },
                 %Mail.Message{
                   headers: %{
                     "content-transfer-encoding" => "base64",
                     "content-type" => ["image/jpeg", {"charset", "us-ascii"}],
                     "content-disposition" => ["attachment", {"filename", "image.jpg"}]
                   },
                   parts: [],
                   multipart: false
                 }
               ]
             } = message
    end

    test "multipart/mixed with multipart/related and inline attachment and multipart/alternative with text/plain and text/html" do
      message =
        Mail.build_multipart()
        |> Mail.put_to("user1@example.com")
        |> Mail.put_from({"User2", "user2@example.com"})
        |> Mail.put_subject("Test email")
        |> Mail.put_attachment({"tiny_jpeg.jpg", @tiny_jpeg_binary})
        |> Mail.put_attachment({"inline_jpeg.jpg", @tiny_jpeg_binary},
          headers: %{
            content_id: "c_id",
            content_type: "image/jpeg",
            x_attachment_id: "a_id",
            content_disposition: ["inline", filename: "image.jpg"]
          }
        )
        |> Mail.put_text("Some text")
        |> Mail.put_html("<h1>Some HTML</h1>")
        |> Mail.Renderers.RFC2822.render()
        |> Mail.Parsers.RFC2822.parse()

      assert %Mail.Message{
               headers: %{"content-type" => ["multipart/mixed", {"boundary", _mixed_boundary}]},
               parts: [
                 %Mail.Message{
                   headers: %{
                     "content-type" => ["multipart/related", {"boundary", _related_boundary}]
                   },
                   parts: [
                     %Mail.Message{
                       headers: %{
                         "content-type" => [
                           "multipart/alternative",
                           {"boundary", _alternative_boundary}
                         ]
                       },
                       parts: [
                         %Mail.Message{
                           headers: %{"content-type" => ["text/plain", {"charset", "UTF-8"}]},
                           body: "Some text",
                           parts: [],
                           multipart: false
                         },
                         %Mail.Message{
                           headers: %{"content-type" => ["text/html", {"charset", "UTF-8"}]},
                           body: "<h1>Some HTML</h1>",
                           parts: [],
                           multipart: false
                         }
                       ]
                     },
                     %Mail.Message{
                       headers: %{
                         "content-transfer-encoding" => "base64",
                         "content-type" => ["image/jpeg", {"charset", "us-ascii"}],
                         "content-id" => "c_id",
                         "content-disposition" => ["inline", {"filename", "image.jpg"}],
                         "x-attachment-id" => "a_id"
                       },
                       parts: [],
                       multipart: false
                     }
                   ]
                 },
                 %Mail.Message{
                   headers: %{
                     "content-transfer-encoding" => "base64",
                     "content-type" => ["image/jpeg", {"charset", "us-ascii"}]
                   },
                   parts: [],
                   multipart: false
                 }
               ]
             } = message
    end

    test "multipart/mixed with only attachments" do
      message =
        Mail.build_multipart()
        |> Mail.put_to("user1@example.com")
        |> Mail.put_from({"User2", "user2@example.com"})
        |> Mail.put_subject("Test email")
        |> Mail.put_attachment({"image.jpg", @tiny_jpeg_binary})
        |> Mail.Renderers.RFC2822.render()
        |> Mail.Parsers.RFC2822.parse()

      assert %Mail.Message{
               headers: %{"content-type" => ["multipart/mixed", {"boundary", _boundary}]},
               parts: [
                 %Mail.Message{
                   headers: %{
                     "content-type" => ["image/jpeg", {"charset", "us-ascii"}],
                     "content-disposition" => ["attachment", {"filename", "image.jpg"}]
                   },
                   parts: [],
                   multipart: false
                 }
               ]
             } = message
    end

    test "multipart/mixed with only inline attachments" do
      message =
        Mail.build_multipart()
        |> Mail.put_to("user1@example.com")
        |> Mail.put_from({"User2", "user2@example.com"})
        |> Mail.put_subject("Test email")
        |> Mail.put_attachment({"inline_jpeg.jpg", @tiny_jpeg_binary},
          headers: %{
            content_id: "c_id",
            content_type: "image/jpeg",
            x_attachment_id: "a_id",
            content_disposition: ["inline", filename: "inline_jpeg.jpg"]
          }
        )
        |> Mail.Renderers.RFC2822.render()
        |> Mail.Parsers.RFC2822.parse()

      assert %Mail.Message{
               headers: %{"content-type" => ["multipart/mixed", {"boundary", _boundary}]},
               parts: [
                 %Mail.Message{
                   headers: %{
                     "content-type" => ["image/jpeg", {"charset", "us-ascii"}],
                     "content-disposition" => ["inline", {"filename", "inline_jpeg.jpg"}]
                   },
                   parts: [],
                   multipart: false
                 }
               ]
             } = message
    end

    test "multipart/mixed with custom headers" do
      message =
        Mail.build_multipart()
        |> Mail.put_from({"User2", "user2@example.com"})
        |> Mail.put_to("user1@example.com")
        |> Mail.Message.put_header("X-Custom-Header", "custom value")
        |> Mail.put_subject("Test email")
        |> Mail.put_attachment({"tiny_jpeg.jpg", @tiny_jpeg_binary})
        |> Mail.put_attachment({"inline_jpeg.jpg", @tiny_jpeg_binary},
          headers: %{
            content_id: "c_id",
            content_type: "image/jpeg",
            x_attachment_id: "a_id",
            content_disposition: ["inline", filename: "image.jpg"]
          }
        )
        |> Mail.put_text("Some text")
        |> Mail.put_html("<h1>Some HTML</h1>")
        |> Mail.Renderers.RFC2822.render()
        |> Mail.Parsers.RFC2822.parse()

      assert %{"x-custom-header" => "custom value"} = message.headers
    end
  end
end
