defmodule Mail.Message do
  defstruct headers: %{},
            body: nil,
            parts: [],
            multipart: false

  @doc """
  Add new part

      Mail.Message.put_part(%Mail.Message{}, %Mail.Message{})
  """
  def put_part(message, %Mail.Message{} = part) do
    put_in(message.parts, message.parts ++ [part])
  end

  @doc """
  Delete a matching part

  Will delete a matching part in the `parts` list. If the part
  is not found no error is raised.
  """
  def delete_part(message, part),
    do: put_in(message.parts, List.delete(message.parts, part))

  @doc """
  Will match on a full or partial content type

      Mail.Message.match_content_type?(message, ~r/text/)
      true

      Mail.Message.match_content_type?(message, "text/html")
      false
  """
  def match_content_type?(message, string_or_regex)

  def match_content_type?(message, %Regex{} = regex) do
    content_type =
      get_content_type(message)
      |> List.first()

    Regex.match?(regex, content_type)
  end

  def match_content_type?(message, type) when is_binary(type),
    do: match_content_type?(message, ~r/#{type}/)

  @doc """
  Add a new header key/value pair

      Mail.Message.put_header(%Mail.Message{}, :content_type, "text/plain")

  The individual headers will be in the `headers` field on the
  `%Mail.Message{}` struct
  """
  def put_header(message, key, content) when not is_binary(key),
    do: put_header(message, to_string(key), content)

  def put_header(message, key, content),
    do: %{message | headers: Map.put(message.headers, fix_header(key), content)}

  def get_header(message, key) when not is_binary(key),
    do: get_header(message, to_string(key))

  def get_header(message, key),
    do: Map.get(message.headers, fix_header(key))

  @doc """
  Deletes a specific header key

      Mail.Message.delete_header(%Mail.Message{headers: %{foo: "bar"}}, :foo)
      %Mail.Message{headers: %{}}
  """
  def delete_header(message, header),
    do: %{message | headers: Map.delete(message.headers, fix_header(header))}

  @doc """
  Deletes a list of headers

      Mail.Message.delete_headers(%Mail.Message{headers: %{foo: "bar", baz: "qux"}}, [:foo, :baz])
      %Mail.Message{headers: %{}}
  """
  def delete_headers(message, headers)
  def delete_headers(message, []), do: message

  def delete_headers(message, [header | tail]),
    do: delete_headers(delete_header(message, header), tail)

  def has_header?(message, header),
    do: Map.has_key?(message.headers, fix_header(header))

  defp fix_header(key) when not is_binary(key),
    do: fix_header(to_string(key))

  defp fix_header(key),
    do: key |> String.downcase() |> String.replace("_", "-")

  @doc """
  Add a new `content-type` header

  The value will always be wrapped in a `List`

      Mail.Message.put_content_type(%Mail.Message{}, "text/plain")
      %Mail.Message{headers: %{content_type: ["text/plain"]}}
  """
  def put_content_type(message, content_type),
    do: put_header(message, :content_type, content_type)

  @doc """
  Gets the `content_type` from the header

  Will ensure the `content_type` is always wraped in a `List`

      Mail.Message.get_content_type(%Mail.Message{})
      [""]

      Mail.Message.get_content_type(%Mail.Message{content_type: "text/plain"})
      ["text/plain"]

      Mail.Message.get_content_type(%Mail.Message{headers: %{content_type: ["multipart/mixed", {"boundary", "foobar"}]}})
      ["multipart/mixed", {"boundary", "foobar"}]
  """
  def get_content_type(message),
    do:
      (get_header(message, :content_type) || "")
      |> List.wrap()

  @doc """
  Adds a boundary value to the `content_type` header

  Will overwrite existing `boundary` key in the list. Will preserve other
  values in the list

      Mail.Message.put_boundary(%Mail.Message{}, "foobar")
      %Mail.Message{headers: %{content_type: ["", {"boundary", "foobar"}]}}

      Mail.Message.put_boundary(%Mail.Message{headers: %{content_type: ["multipart/mixed", {"boundary", "bazqux"}]}})
      %Mail.Message{headers: %{content_type: ["multipart/mixed", {"boundary", "foobar"}]}}
  """
  def put_boundary(message, boundary) do
    content_type =
      get_content_type(message)
      |> Mail.Proplist.put("boundary", boundary)

    put_content_type(message, content_type)
  end

  @doc """
  Gets the boundary value from the `content_type` header

  Will retrieve the boundary value. If one is not set a random one is generated.

      Mail.Message.get_boundary(%Mail.Message{headers: %{content_type: ["multipart/mixed", {"boundary", "foobar"}]}})
      "foobar"

      Mail.Message.get_boundary(%Mail.Message{headers: %{content_type: ["multipart/mixed"]}})
      "ASDFSHNEW3473423"
  """
  def get_boundary(message) do
    message
    |> get_content_type()
    |> Mail.Proplist.get("boundary")
    |> case do
      nil -> generate_boundary()
      boundary -> boundary
    end
  end

  defp generate_boundary do
    :crypto.strong_rand_bytes(12) |> Base.encode16()
  end

  @doc """
  Sets the `body` field on the part

      Mail.Message.put_body(%Mail.Message{}, "Some data")
      %Mail.Message{body: "Some Data", headers: %{}}
  """
  def put_body(part, body),
    do: put_in(part.body, body)

  @doc """
  Build a new text message

      Mail.Message.build_text("Some text")
      %Mail.Message{body: "Some text", headers: %{content_type: "text/plain"}}
  """
  def build_text(body),
    do:
      put_content_type(%Mail.Message{}, "text/plain")
      |> put_header(:content_transfer_encoding, :quoted_printable)
      |> put_body(body)

  @doc """
  Build a new HTML message

      Mail.Message.build_html("<h1>Some HTML</h1>")
      %Mail.Message{body: "<h1>Some HTML</h1>", headers: %{content_type: "text/html"}}
  """
  def build_html(body),
    do:
      put_content_type(%Mail.Message{}, "text/html")
      |> put_header(:content_transfer_encoding, :quoted_printable)
      |> put_body(body)

  @doc """
  Add attachment meta data to a `Mail.Message`

  Will allow you to create a new part that is meant to be used as an
  attachment.

  You can pass either a filepath or a tuple as the second argument. If a
  tuple is being passed the tuple must only have two elements:
  `{filename, filedata}`.

  The mimetype of the file is determined by the file extension.

      Mail.Message.build_attachment("README.md")
      %Mail.Message{data: "base64 encoded", headers: %{content_type: ["text/x-markdown"], content_disposition: ["attachment", filename: "README.md"], content_transfer_encoding: :base64}}

      Mail.Message.build_attachment({"README.md", "file contents})
      %Mail.Message{data: "base64 encoded", headers: %{content_type: ["text/x-markdown"], content_disposition: ["attachment", filename: "README.md"], content_transfer_encoding: :base64}}

  ## Options

  * `:encoding` - Valid values: `:base64`
  * `:content_type` - override the mimetype, will autodetermine based upon file extension otherwise

  ## Custom mimetype library

  By default `Mail` will use its own internal mimetype adapter. However,
  you may want to rely on `Plug` and the custom mimetypes that you have
  created for it. You can override the mimetype function in the
  `config.exs` of your application:

      config :mail, mimetype_fn: &CustomMimeAdapter.type/1

  This function should take a string that is the file extension. It
  should return a single mimetype.

      CustomMimeAdapter.type("md")
      "text/markdown"
  """
  def build_attachment(path_or_file_tuple)

  def build_attachment(path) when is_binary(path),
    do: put_attachment(%Mail.Message{}, path)

  def build_attachment(file) when is_tuple(file),
    do: put_attachment(%Mail.Message{}, file)

  @doc """
  Adds a new attachment part to the provided message

  The first argument must be a `Mail.Message`. The remaining argument is descibed in `build_attachment/1`

      Mail.Message.put_attachment(%Mail.Message{}, "README.md")
      %Mail.Message{data: "base64 encoded", headers: %{content_type: ["text/x-markdown"], content_disposition: ["attachment", filename: "README.md"], content_transfer_encoding: :base64}}

      Mail.Message.put_attachment(%Mail.Message{}, {"README.md", "file contents})
      %Mail.Message{data: "base64 encoded", headers: %{content_type: ["text/x-markdown"], content_disposition: ["attachment", filename: "README.md"], content_transfer_encoding: :base64}}
  """
  def put_attachment(message, path_or_file_tuple)

  def put_attachment(%Mail.Message{} = message, path) when is_binary(path) do
    {:ok, data} = File.read(path)
    basename = Path.basename(path)
    put_attachment(message, {basename, data})
  end

  def put_attachment(%Mail.Message{} = message, {filename, data}) do
    filename = Path.basename(filename)

    put_body(message, data)
    |> put_content_type(mimetype(filename))
    |> put_header(:content_disposition, ["attachment", {"filename", filename}])
    |> put_header(:content_transfer_encoding, :base64)
  end

  @doc """
  Is the part an attachment or not

  Returns `Boolean`
  """
  def is_attachment?(message),
    do: Enum.member?(List.wrap(get_header(message, :content_disposition)), "attachment")

  @doc """
  Determines the message has any attachment parts

  Returns a `Boolean`
  """
  def has_attachment?(parts) when is_list(parts),
    do: has_part?(parts, &is_attachment?/1)

  def has_attachment?(message),
    do: has_attachment?(message.parts)

  @doc """
  Is the message text based or not

  Can be a message with a `content_type` of `text/plain` or `text/html`

  Returns `Boolean`
  """
  def is_text_part?(message) do
    match_content_type?(message, ~r/text\/(plain|html)/)
  end

  @doc """
  Determines the message has any text (`text/plain` or `text/html`) parts

  Returns a `Boolean`
  """
  def has_text_part?(parts) when is_list(parts),
    do: has_part?(parts, &is_text_part?/1)

  def has_text_part?(message),
    do: has_text_part?(message.parts)

  defp has_part?(parts, fun),
    do: Enum.any?(parts, &fun.(&1))

  defp mimetype(filename) do
    mimetype_fn = Application.get_env(:mail, :mimetype_fn) || (&Mail.MIME.type/1)

    extension =
      Path.extname(filename)
      |> String.split(".")
      |> List.last()

    mimetype_fn.(extension)
  end
end
