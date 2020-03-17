defmodule Pdf do
  use GenServer
  import Pdf.Util.GenServerMacros
  alias Pdf.Document

  def new(opts \\ []), do: GenServer.start_link(__MODULE__, opts)

  def open(opts \\ [], func) do
    {:ok, pdf} = new(opts)
    func.(pdf)
    delete(pdf)
    :ok
  end

  def delete(pdf), do: GenServer.stop(pdf)

  def init(opts), do: {:ok, Document.new(opts)}

  defcall write_to(path, _from, document) do
    File.write!(path, Document.to_iolist(document))
    {:reply, self(), document}
  end

  defcall export(_from, document) do
    {:reply, Document.to_iolist(document) |> :binary.list_to_bin(), document}
  end

  @type color_name :: atom
  @type rgb :: {integer, integer, integer} | {float, float, float}
  @type cmyk :: {float, float, float, float}
  @spec set_fill_color(pid, color_name | rgb | cmyk) :: pid
  defcall set_fill_color(color, _from, document) do
    {:reply, self(), Document.set_fill_color(document, color)}
  end

  @spec set_stroke_color(pid, color_name | rgb | cmyk) :: pid
  defcall set_stroke_color(color, _from, document) do
    {:reply, self(), Document.set_stroke_color(document, color)}
  end

  @spec set_line_width(pid, integer) :: pid
  defcall set_line_width(width, _from, document) do
    {:reply, self(), Document.set_line_width(document, width)}
  end

  @type x :: integer
  @type y :: integer
  @type width :: integer
  @type height :: integer

  @spec rectangle(pid, {x, y}, {width, height}) :: pid
  defcall rectangle({x, y}, {w, h}, _from, document) do
    {:reply, self(), Document.rectangle(document, {x, y}, {w, h})}
  end

  @spec line(pid, {x, y}, {x, y}) :: pid
  defcall line({x, y}, {x2, y2}, _from, document) do
    {:reply, self(), Document.line(document, {x, y}, {x2, y2})}
  end

  @spec move_to(pid, {x, y}) :: pid
  defcall move_to({x, y}, _from, document) do
    {:reply, self(), Document.move_to(document, {x, y})}
  end

  @spec line_append(pid, {x, y}) :: pid
  defcall line_append({x, y}, _from, document) do
    {:reply, self(), Document.line_append(document, {x, y})}
  end

  @spec stroke(pid) :: pid
  defcall stroke(_from, document) do
    {:reply, self(), Document.stroke(document)}
  end

  def set_font(pid, font_name, opts) when is_list(opts) do
    font_size = Keyword.get(opts, :size, 16)
    set_font(pid, font_name, font_size, Keyword.delete(opts, :size))
  end

  def set_font(pid, font_name, font_size) when is_integer(font_size) do
    set_font(pid, font_name, font_size, [])
  end

  defcall set_font(font_name, font_size, opts, _from, document) do
    {:reply, self(), Document.set_font(document, font_name, font_size, opts)}
  end

  defcall add_font(path, _from, document) do
    {:reply, self(), Document.add_external_font(document, path)}
  end

  defcall set_text_leading(leading, _from, document) do
    {:reply, self(), Document.set_text_leading(document, leading)}
  end

  defcall text_at({x, y}, text, _from, document) do
    {:reply, self(), Document.text_at(document, {x, y}, text)}
  end

  defcall text_at({x, y}, text, opts, _from, document) do
    {:reply, self(), Document.text_at(document, {x, y}, text, opts)}
  end

  defcall text_wrap({x, y}, {w, h}, text, _from, document) do
    {document, remaining} = Document.text_wrap(document, {x, y}, {w, h}, text)
    {:reply, {self(), remaining}, document}
  end

  defcall text_wrap({x, y}, {w, h}, text, opts, _from, document) do
    {document, remaining} = Document.text_wrap(document, {x, y}, {w, h}, text, opts)
    {:reply, {self(), remaining}, document}
  end

  defcall text_lines({x, y}, [_ | _] = lines, opts, _from, document) do
    {:reply, self(), Document.text_lines(document, {x, y}, lines, opts)}
  end

  defcall text_lines({x, y}, [_ | _] = lines, _from, document) do
    {:reply, self(), Document.text_lines(document, {x, y}, lines)}
  end

  def add_image(pid, {x, y}, image_path), do: add_image(pid, {x, y}, image_path, [])

  defcall add_image({x, y}, image_path, opts, _from, document) do
    {:reply, self(), Document.add_image(document, {x, y}, image_path, opts)}
  end

  defcall size(_from, document) do
    {:reply, Document.size(document), document}
  end

  defcall cursor(_from, document) do
    {:reply, Document.cursor(document), document}
  end

  defcall move_down(amount, _from, document) do
    {:reply, self(), Document.move_down(document, amount)}
  end

  @doc """
  Sets the author in the PDF information section.
  """
  defcall(set_author(author, _from, state), do: set_info(:author, author, state))

  @doc """
  Sets the creator in the PDF information section.
  """
  defcall(set_creator(creator, _from, state), do: set_info(:creator, creator, state))

  @doc """
  Sets the keywords in the PDF information section.
  """
  defcall(set_keywords(keywords, _from, state), do: set_info(:keywords, keywords, state))

  @doc """
  Sets the producer in the PDF information section.
  """
  defcall(set_producer(producer, _from, state), do: set_info(:producer, producer, state))

  @doc """
  Sets the subject in the PDF information section.
  """
  defcall(set_subject(subject, _from, state), do: set_info(:subject, subject, state))

  @doc """
  Sets the title in the PDF information section.
  """
  defcall(set_title(title, _from, state), do: set_info(:title, title, state))

  @doc """
  Set multiple keys in the PDF information setion.

  Valid keys
    - `:title`
    - `:producer`
    - `:creator`
    - `:created`
    - `:modified`
    - `:keywords`
    - `:author`
    - `:subject`
  """
  @type info_list :: keyword
  @spec set_info(pid, info_list) :: pid
  defcall set_info(info_list, _from, document) do
    {:reply, self(), Document.put_info(document, info_list)}
  end

  defp set_info(key, value, document) do
    {:reply, self(), Document.put_info(document, key, value)}
  end
end
