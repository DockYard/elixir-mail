defmodule Mail.Renderers.RFC2822Test do
  use ExUnit.Case
  import Mail.Assertions.RFC2822

  test "header - capitalizes and hyphenates keys, joins lists according to spec" do
    header = Mail.Renderers.RFC2822.render_header(:foo_bar, ["abcd", baz_buzz: "qux"])
    assert header == "Foo-Bar: abcd; baz-buzz=qux"
  end

  test "to header renders list of recipients" do
    header = Mail.Renderers.RFC2822.render_header(:to, "user1@example.com")
    assert header == "To: user1@example.com"

    header = Mail.Renderers.RFC2822.render_header(:to, ["user1@example.com", "user2@example.com"])
    assert header == "To: user1@example.com, user2@example.com"
  end

  test "renders simple key / value pair header" do
    header = Mail.Renderers.RFC2822.render_header(:subject, "Hello World!")
    assert header == "Subject: Hello World!"
  end

  test "headers - renders all headers" do
    headers = Mail.Renderers.RFC2822.render_headers(%{foo: "bar", baz: "qux"})
    assert headers == "Foo: bar\nBaz: qux"
  end

  test "headers - blacklist certain headers" do
    headers = Mail.Renderers.RFC2822.render_headers(%{foo: "bar", baz: "qux"}, [:foo, :baz])
    assert headers == ""
  end

  test "renders each part recursively" do
    sub_part_1 = Mail.Message.build_text("Hello there!")
    sub_part_2 = Mail.Message.build_html("<h1>Hello there!</h1>")

    part =
      Mail.build_multipart()
      |> Mail.Message.put_content_type("mutipart/alternative")
      |> Mail.Message.put_boundary("foobar")
      |> Mail.Message.put_part(sub_part_1)
      |> Mail.Message.put_part(sub_part_2)

    result = Mail.Renderers.RFC2822.render_part(part) <> "\n"
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

    result = Mail.Renderers.RFC2822.render(message) <> "\n"

    assert result == fixture
  end

  test "renders a multipart mail" do
    message =
      Mail.build_multipart()
      |> Mail.put_to("user@example.com")
      |> Mail.put_subject("Test email")
      |> Mail.put_text("Some text")
      |> Mail.put_html("<h1>Some HTML</h1>")
      |> Mail.Message.put_boundary("foobar")

    {:ok, fixture} = File.read("test/fixtures/simple-multipart-rendering.eml")

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

    refute Map.has_key?(message.headers, :bcc)
  end
end
