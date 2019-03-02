defmodule Mail.Encoders.QuotedPrintableTest do
  use ExUnit.Case, async: true

  test "encodes empty string" do
    assert Mail.Encoders.QuotedPrintable.encode("") == ""
  end

  test "encodes safe characters as themselves" do
    ascii_lower = "abcdefghijklmnopqrstuvwxyz"
    assert Mail.Encoders.QuotedPrintable.encode(ascii_lower) == ascii_lower

    ascii_upper = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    assert Mail.Encoders.QuotedPrintable.encode(ascii_upper) == ascii_upper

    ascii_symbols = "!\"#$%&\'()*+,-./0123456789:;<>?@[\\]^_`{|}~"
    assert Mail.Encoders.QuotedPrintable.encode(ascii_symbols) == ascii_symbols
  end

  test "encodes equal sign" do
    assert Mail.Encoders.QuotedPrintable.encode("hello=goodbye") == "hello=3Dgoodbye"
  end

  test "encodes trailing space" do
    assert Mail.Encoders.QuotedPrintable.encode("hello ") == "hello=20"
  end

  test "encodes trailing tab" do
    assert Mail.Encoders.QuotedPrintable.encode("hello\t") == "hello=09"
  end

  test "encodes <CR><LF>" do
    assert Mail.Encoders.QuotedPrintable.encode("foo\r\nbar") == "foo=0D=0Abar"
  end

  test "encodes UTF-8 characters" do
    assert Mail.Encoders.QuotedPrintable.encode("façade") == "fa=C3=A7ade"
  end

  test "encodes escaped UTF-8 characters" do
    assert Mail.Encoders.QuotedPrintable.encode("fa\u00E7ade") == "fa=C3=A7ade"
  end

  test "encodes lines longer than 76 characters using soft line breaks" do
    message = """
    Lorem ipsum dolor sit amet, consectetuer adipiscing elit, sed diam nonummy \
    nibh euismod tincidunt ut laoreet dolore magna aliquam erat volutpat. Ut \
    wisi enim ad minim veniam, quis nostrud exerci tation ullamcorper \
    suscipit lobortis nisl ut aliquip ex ea commodo consequat.\
    """

    encoding = """
    Lorem ipsum dolor sit amet, consectetuer adipiscing elit, sed diam nonummy =\r\n\
    nibh euismod tincidunt ut laoreet dolore magna aliquam erat volutpat. Ut wi=\r\n\
    si enim ad minim veniam, quis nostrud exerci tation ullamcorper suscipit lo=\r\n\
    bortis nisl ut aliquip ex ea commodo consequat.\
    """

    assert Mail.Encoders.QuotedPrintable.encode(message) == encoding
  end

  test "encodes 73 chars ending with an equal sign" do
    message = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx="
    encoding = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx=3D"
    assert Mail.Encoders.QuotedPrintable.encode(message) == encoding
  end

  test "encodes 74 chars ending with an equal sign" do
    message = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx="
    encoding = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx=\r\n=3D"
    assert Mail.Encoders.QuotedPrintable.encode(message) == encoding
  end

  test "encodes 75 chars ending with an equal sign" do
    message = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx="

    encoding =
      "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx=\r\n=3D"

    assert Mail.Encoders.QuotedPrintable.encode(message) == encoding
  end

  test "encodes 76 chars ending with an equal sign" do
    message = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx="

    encoding =
      "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx=\r\n=3D"

    assert Mail.Encoders.QuotedPrintable.encode(message) == encoding
  end

  test "encodes 77 chars ending with an equal sign" do
    message = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx="

    encoding =
      "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx=\r\nx=3D"

    assert Mail.Encoders.QuotedPrintable.encode(message) == encoding
  end

  test "encodes 73 chars ending with a space" do
    message = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx "
    encoding = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx=20"
    assert Mail.Encoders.QuotedPrintable.encode(message) == encoding
  end

  test "encodes 74 chars ending with a space" do
    message = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx "
    encoding = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx=20"
    assert Mail.Encoders.QuotedPrintable.encode(message) == encoding
  end

  test "encodes 75 chars ending with a space" do
    message = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx "

    encoding =
      "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx=\r\n=20"

    assert Mail.Encoders.QuotedPrintable.encode(message) == encoding
  end

  test "encodes 76 chars ending with a space" do
    message = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx "

    encoding =
      "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx=\r\n=20"

    assert Mail.Encoders.QuotedPrintable.encode(message) == encoding
  end

  test "encodes 77 chars ending with a space" do
    message = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx "

    encoding =
      "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx=\r\nx=20"

    assert Mail.Encoders.QuotedPrintable.encode(message) == encoding
  end

  test "decodes empty string" do
    assert Mail.Encoders.QuotedPrintable.decode("") == ""
  end

  test "decodes safe characters as themselves" do
    ascii_lower = "abcdefghijklmnopqrstuvwxyz"
    assert Mail.Encoders.QuotedPrintable.decode(ascii_lower) == ascii_lower

    ascii_upper = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    assert Mail.Encoders.QuotedPrintable.decode(ascii_upper) == ascii_upper

    ascii_symbols = "!\"#$%&\'()*+,-./0123456789:;<>?@[\\]^_`{|}~"
    assert Mail.Encoders.QuotedPrintable.decode(ascii_symbols) == ascii_symbols
  end

  test "decodes equal sign" do
    assert Mail.Encoders.QuotedPrintable.decode("hello=3Dgoodbye") == "hello=goodbye"
  end

  test "decodes UTF-8 characters" do
    assert Mail.Encoders.QuotedPrintable.decode("fa=C3=A7ade") == "façade"
  end

  test "decodes <CR><LF>" do
    assert Mail.Encoders.QuotedPrintable.decode("foo=0D=0Abar") == "foo\r\nbar"
  end

  test "decodes hard new lines" do
    assert Mail.Encoders.QuotedPrintable.decode("foo\nbar") == "foo\nbar"
  end

  test "decodes soft line breaks" do
    encoding = "Now's the time =\r\nfor all folk to come=\r\n to the aid of their country."
    decoding = "Now's the time for all folk to come to the aid of their country."
    assert Mail.Encoders.QuotedPrintable.decode(encoding) == decoding
  end

  test "decodes lines longer than 76 characters" do
    encoding = """
    Lorem ipsum dolor sit amet, consectetuer adipiscing elit, sed diam nonummy =\r\n\
    nibh euismod tincidunt ut laoreet dolore magna aliquam erat volutpat. Ut wi=\r\n\
    si enim ad minim veniam, quis nostrud exerci tation ullamcorper suscipit lo=\r\n\
    bortis nisl ut aliquip ex ea commodo consequat.\
    """

    decoding = """
    Lorem ipsum dolor sit amet, consectetuer adipiscing elit, sed diam nonummy \
    nibh euismod tincidunt ut laoreet dolore magna aliquam erat volutpat. Ut \
    wisi enim ad minim veniam, quis nostrud exerci tation ullamcorper \
    suscipit lobortis nisl ut aliquip ex ea commodo consequat.\
    """

    assert Mail.Encoders.QuotedPrintable.decode(encoding) == decoding
  end

  test "decodes lowercase case escape sequences as if uppercase per RFC" do
    assert Mail.Encoders.QuotedPrintable.decode("hello=3d") == "hello="
  end

  test "decodes illegal escape sequences by returning them unaltered per RFC" do
    assert Mail.Encoders.QuotedPrintable.decode("foo=") == "foo="
    assert Mail.Encoders.QuotedPrintable.decode("foo=A") == "foo=A"
    assert Mail.Encoders.QuotedPrintable.decode("foo=Ax") == "foo=Ax"
    assert Mail.Encoders.QuotedPrintable.decode("foo=Ax=xy") == "foo=Ax=xy"
    assert Mail.Encoders.QuotedPrintable.decode("foo=XY") == "foo=XY"
    assert Mail.Encoders.QuotedPrintable.decode("foo=X") == "foo=X"
  end
end
