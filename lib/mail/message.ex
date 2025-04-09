defmodule Mail.Message do
  defstruct headers: %{},
            body: nil,
            parts: [],
            multipart: false

  @type t :: %__MODULE__{}

  @doc """
  Add new part

  ## Examples

      iex> Mail.Message.put_part(%Mail.Message{}, %Mail.Message{})
      %Mail.Message{parts: [%Mail.Message{}]}
  """
  def put_part(message, %Mail.Message{} = part) do
    put_in(message.parts, message.parts ++ [part])
  end

  def put_parts(message, parts) when is_list(parts) do
    put_in(message.parts, message.parts ++ parts)
  end

  def replace_part(message, match_fun, %Mail.Message{} = part) when is_function(match_fun, 1) do
    parts =
      message.parts
      |> Enum.reject(match_fun)
      |> Kernel.++([part])

    %{message | parts: parts}
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

  ## Examples

      iex> message = %Mail.Message{headers: %{"content-type" => ["text/plain", {"charset", "UTF-8"}]}}
      iex> Mail.Message.match_content_type?(message, ~r/text/)
      true

      iex> message = %Mail.Message{headers: %{"content-type" => ["text/plain", {"charset", "UTF-8"}]}}
      iex> Mail.Message.match_content_type?(message, "text/html")
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

  def match_body_text(%{headers: %{"content-disposition" => ["attachment" | _]}}), do: false
  def match_body_text(message), do: Mail.Message.match_content_type?(message, "text/plain")

  @doc """
  Add a new header key/value pair

  ## Examples

      iex> Mail.Message.put_header(%Mail.Message{}, :content_type, "text/plain")
      %Mail.Message{headers: %{"content-type" => "text/plain"}}

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

  ## Examples

      iex> Mail.Message.delete_header(%Mail.Message{headers: %{"foo" => "bar"}}, :foo)
      %Mail.Message{headers: %{}}
  """
  def delete_header(message, header),
    do: %{message | headers: Map.delete(message.headers, fix_header(header))}

  @doc """
  Deletes a list of headers

  ## Examples

      iex> Mail.Message.delete_headers(%Mail.Message{headers: %{"foo" => "bar", "baz" => "qux"}}, [:foo, :baz])
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

  ## Examples

      iex> Mail.Message.put_content_type(%Mail.Message{}, "text/plain")
      %Mail.Message{headers: %{"content-type" => ["text/plain"]}}

      iex> Mail.Message.put_content_type(%Mail.Message{}, ["text/plain", {"charset", "UTF-8"}])
      %Mail.Message{headers: %{"content-type" => ["text/plain", {"charset", "UTF-8"}]}}
  """
  def put_content_type(message, content_type) when is_binary(content_type),
    do: put_content_type(message, [content_type])

  def put_content_type(message, content_type) do
    put_header(message, :content_type, content_type)
  end

  @doc """
  Gets the `content_type` from the header

  Will ensure the `content_type` is always wrapped in a `List`

  ## Examples

      iex> Mail.Message.get_content_type(%Mail.Message{})
      [""]

      iex> Mail.Message.get_content_type(%Mail.Message{headers: %{"content-type" => "text/plain"}})
      ["text/plain"]

      iex> Mail.Message.get_content_type(%Mail.Message{headers: %{"content-type" => ["multipart/mixed", {"boundary", "foobar"}]}})
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

  ## Examples

      iex> Mail.Message.put_boundary(%Mail.Message{}, "foobar")
      %Mail.Message{headers: %{"content-type" => ["", {"boundary", "foobar"}]}}

      iex> Mail.Message.put_boundary(%Mail.Message{headers: %{"content-type" => ["multipart/mixed", {"boundary", "bazqux"}]}}, "foobar")
      %Mail.Message{headers: %{"content-type" => ["multipart/mixed", {"boundary", "foobar"}]}}
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

  ## Examples

      iex> Mail.Message.get_boundary(%Mail.Message{headers: %{"content-type" => ["multipart/mixed", {"boundary", "foobar"}]}})
      "foobar"

      iex> Mail.Message.get_boundary(%Mail.Message{headers: %{"content-type" => ["multipart/mixed", {"boundary", "ASDFSHNEW3473423"}]}})
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

  ## Examples

      iex> Mail.Message.put_body(%Mail.Message{}, "Some Data")
      %Mail.Message{body: "Some Data", headers: %{}}
  """
  def put_body(part, body),
    do: put_in(part.body, body)

  @doc """
  Build a new text message

  ## Examples

      iex> Mail.Message.build_text("Some text")
      %Mail.Message{body: "Some text", headers: %{"content-type" => ["text/plain", {"charset", "UTF-8"}], "content-transfer-encoding" => :quoted_printable}}

      iex> Mail.Message.build_text("Some text", charset: "us-ascii")
      %Mail.Message{body: "Some text", headers: %{"content-type" => ["text/plain", {"charset", "us-ascii"}], "content-transfer-encoding" => :quoted_printable}}

  ## Options

  * `:charset` - The character encoding standard for content type
  """
  def build_text(body, opts \\ []) do
    content_type =
      case opts do
        charset: charset ->
          ["text/plain", {"charset", charset}]

        _else ->
          ["text/plain", {"charset", default_charset()}]
      end

    put_content_type(%Mail.Message{}, content_type)
    |> put_header(:content_transfer_encoding, :quoted_printable)
    |> put_body(body)
  end

  @doc """
  Build a new HTML message

  ## Examples

      iex> Mail.Message.build_html("<h1>Some HTML</h1>")
      %Mail.Message{body: "<h1>Some HTML</h1>", headers: %{"content-type" => ["text/html", {"charset", "UTF-8"}], "content-transfer-encoding" => :quoted_printable}}

      iex> Mail.Message.build_html("<h1>Some HTML</h1>", charset: "UTF-8")
      %Mail.Message{body: "<h1>Some HTML</h1>", headers: %{"content-type" => ["text/html", {"charset", "UTF-8"}], "content-transfer-encoding" => :quoted_printable}}

  ## Options

  * `:charset` - The character encoding standard for content type
  """
  def build_html(body, opts \\ []) do
    content_type =
      case opts do
        charset: charset ->
          ["text/html", {"charset", charset}]

        _else ->
          ["text/html", {"charset", default_charset()}]
      end

    put_content_type(%Mail.Message{}, content_type)
    |> put_header(:content_transfer_encoding, :quoted_printable)
    |> put_body(body)
  end

  defp default_charset do
    "UTF-8"
  end

  @doc """
  Add attachment meta data to a `Mail.Message`

  Will allow you to create a new part that is meant to be used as an
  attachment.

  You can pass either a filepath or a tuple as the second argument. If a
  tuple is being passed the tuple must only have two elements:
  `{filename, filedata}`.

  The mimetype of the file is determined by the file extension.

  ## Examples

      iex> message = Mail.Message.build_attachment("README.md")
      %Mail.Message{body: <<"# Mail\\n", _::binary>>, headers: %{"content-type" => ["text/markdown"], "content-disposition" => ["attachment", {"filename", "README.md"}], "content-transfer-encoding" => :base64}} = message

      iex> message = Mail.Message.build_attachment({"README.md", "file contents"})
      %Mail.Message{body: "file contents", headers: %{"content-type" => ["text/markdown"], "content-disposition" => ["attachment", {"filename", "README.md"}], "content-transfer-encoding" => :base64}} = message

  ## Options

  See `put_attachment/3` for options

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
  def build_attachment(path_or_file_tuple, opts \\ [])

  def build_attachment(path, opts) when is_binary(path),
    do: put_attachment(%Mail.Message{}, path, opts)

  def build_attachment(file, opts) when is_tuple(file),
    do: put_attachment(%Mail.Message{}, file, opts)

  @doc """
  Adds a new attachment part to the provided message

  The first argument must be a `Mail.Message`. The remaining argument is described in `build_attachment/1`

  ## Options
    * `:headers` - Headers to be merged

  ## Examples

      iex> message = Mail.Message.put_attachment(%Mail.Message{}, "README.md")
      %Mail.Message{body: <<"# Mail\\n", _::binary>>, headers: %{"content-type" => ["text/markdown"], "content-disposition" => ["attachment", {"filename", "README.md"}], "content-transfer-encoding" => :base64}} = message

      iex> Mail.Message.put_attachment(%Mail.Message{}, {"README.md", "file contents"})
      %Mail.Message{body: "file contents", headers: %{"content-type" => ["text/markdown"], "content-disposition" => ["attachment", {"filename", "README.md"}], "content-transfer-encoding" => :base64}}

  ### Adding custom headers

      iex> message =Mail.Message.put_attachment(%Mail.Message{}, "README.md", headers: [content_id: "attachment-id"])
      %Mail.Message{body: <<"# Mail\\n", _::binary>>, headers: %{"content-type" => ["text/markdown"], "content-disposition" => ["attachment", {"filename", "README.md"}], "content-transfer-encoding" => :base64, "content-id" => "attachment-id"}} = message

      iex> message = Mail.Message.put_attachment(%Mail.Message{}, {"README.md", "file contents"}, headers: [content_id: "attachment-id"])
      %Mail.Message{body: "file contents", headers: %{"content-type" => ["text/markdown"], "content-disposition" => ["attachment", {"filename", "README.md"}], "content-transfer-encoding" => :base64, "content-id" => "attachment-id"}} = message
  """
  def put_attachment(message, path_or_file_tuple, opts \\ [])

  def put_attachment(%Mail.Message{} = message, path, opts) when is_binary(path) do
    {:ok, data} = File.read(path)
    basename = Path.basename(path)
    put_attachment(message, {basename, data}, opts)
  end

  def put_attachment(%Mail.Message{} = message, {filename, data}, opts) do
    filename = Path.basename(filename)

    message
    |> put_body(data)
    |> put_content_type(mimetype(filename))
    |> put_header(:content_disposition, ["attachment", {"filename", filename}])
    |> put_header(:content_transfer_encoding, :base64)
    |> merge_headers(opts)
  end

  defp merge_headers(message, opts) do
    Enum.reduce(opts[:headers] || [], message, fn {k, v}, acc -> put_header(acc, k, v) end)
  end

  @doc """
  Is the part an attachment or not

  Types:
  - `:all` - all attachments
  - `:attachment` - only attachments (default)
  - `:inline` - only inline attachments

  Returns `Boolean`
  """
  @spec is_attachment?(Mail.Message.t(), :all | :attachment | :inline) :: boolean()
  def is_attachment?(message, type \\ :attachment) do
    types =
      case type do
        :all -> ["attachment", "inline"]
        :attachment -> ["attachment"]
        :inline -> ["inline"]
      end

    case List.wrap(get_header(message, :content_disposition)) do
      [disposition | _] -> disposition in types
      _ -> false
    end
  end

  @doc """
  Determines the message has any attachment parts

  Returns a `Boolean`
  """
  def has_attachment?(parts, type \\ :attachment)

  def has_attachment?(parts, type) when is_list(parts),
    do: has_part?(parts, &is_attachment?(&1, type))

  def has_attachment?(message, type),
    do: has_attachment?(message.parts, type)

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
