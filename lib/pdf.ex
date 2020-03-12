defmodule Pdf do
  defmodule State do
    @moduledoc false
    defstruct document: nil
  end

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

  def init(_args), do: {:ok, %State{document: Document.new()}}

  defcall write_to(path, _from, %State{document: document} = state) do
    File.write!(path, Document.to_iolist(document))
    {:reply, self(), state}
  end

  defcall export(_from, %State{document: document} = state) do
    {:reply, Document.to_iolist(document) |> :binary.list_to_bin(), state}
  end

  @type color_name :: atom
  @type rgb :: {integer, integer, integer} | {float, float, float}
  @type cmyk :: {float, float, float, float}
  @spec set_fill_color(pid, color_name | rgb | cmyk) :: pid
  defcall set_fill_color(color, _from, %State{document: document} = state) do
    document = Document.set_fill_color(document, color)
    {:reply, self(), %{state | document: document}}
  end

  @spec set_stroke_color(pid, color_name | rgb | cmyk) :: pid
  defcall set_stroke_color(color, _from, %State{document: document} = state) do
    document = Document.set_stroke_color(document, color)
    {:reply, self(), %{state | document: document}}
  end

  @spec set_line_width(pid, integer) :: pid
  defcall set_line_width(width, _from, %State{document: document} = state) do
    document = Document.set_line_width(document, width)
    {:reply, self(), %{state | document: document}}
  end

  @type x :: integer
  @type y :: integer
  @type width :: integer
  @type height :: integer

  @spec rectangle(pid, {x, y}, {width, height}) :: pid
  defcall rectangle({x, y}, {w, h}, _from, %State{document: document} = state) do
    document = Document.rectangle(document, {x, y}, {w, h})
    {:reply, self(), %{state | document: document}}
  end

  @spec line(pid, {x, y}, {x, y}) :: pid
  defcall line({x, y}, {x2, y2}, _from, %State{document: document} = state) do
    document = Document.line(document, {x, y}, {x2, y2})
    {:reply, self(), %{state | document: document}}
  end

  @spec move_to(pid, {x, y}) :: pid
  defcall move_to({x, y}, _from, %State{document: document} = state) do
    document = Document.move_to(document, {x, y})
    {:reply, self(), %{state | document: document}}
  end

  @spec line_append(pid, {x, y}) :: pid
  defcall line_append({x, y}, _from, %State{document: document} = state) do
    document = Document.line_append(document, {x, y})
    {:reply, self(), %{state | document: document}}
  end

  @spec stroke(pid) :: pid
  defcall stroke(_from, %State{document: document} = state) do
    document = Document.stroke(document)
    {:reply, self(), %{state | document: document}}
  end

  defcall set_font(font_name, font_size, _from, %State{document: document} = state) do
    document = Document.set_font(document, font_name, font_size)
    {:reply, self(), %{state | document: document}}
  end

  defcall add_font(path, _from, %State{document: document} = state) do
    document = Document.add_external_font(document, path)
    {:reply, self(), %{state | document: document}}
  end

  defcall set_text_leading(leading, _from, %State{document: document} = state) do
    document = Document.set_text_leading(document, leading)
    {:reply, self(), %{state | document: document}}
  end

  defcall text_at({x, y}, text, _from, %State{document: document} = state) do
    document = Document.text_at(document, {x, y}, text)
    {:reply, self(), %{state | document: document}}
  end

  defcall text_at({x, y}, text, opts, _from, %State{document: document} = state) do
    document = Document.text_at(document, {x, y}, text, opts)
    {:reply, self(), %{state | document: document}}
  end

  defcall text_wrap({x, y}, {w, h}, text, _from, %State{document: document} = state) do
    document = Document.text_wrap(document, {x, y}, {w, h}, text)
    {:reply, self(), %{state | document: document}}
  end

  defcall text_wrap({x, y}, {w, h}, text, opts, _from, %State{document: document} = state) do
    document = Document.text_wrap(document, {x, y}, {w, h}, text, opts)
    {:reply, self(), %{state | document: document}}
  end

  defcall text_lines({x, y}, [_ | _] = lines, opts, _from, %State{document: document} = state) do
    document = Document.text_lines(document, {x, y}, lines, opts)
    {:reply, self(), %{state | document: document}}
  end

  defcall text_lines({x, y}, [_ | _] = lines, _from, %State{document: document} = state) do
    document = Document.text_lines(document, {x, y}, lines)
    {:reply, self(), %{state | document: document}}
  end

  defcall(
    add_image({x, y}, image_path, _from, %State{document: document} = state),
    do: {:reply, self(), %{state | document: Document.add_image(document, {x, y}, image_path)}}
  )

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
  defcall set_info(info_list, _from, %State{document: document} = state) do
    document = Document.put_info(document, info_list)
    {:reply, self(), %{state | document: document}}
  end

  defp set_info(key, value, %State{document: document} = state) do
    document = Document.put_info(document, key, value)
    {:reply, self(), %{state | document: document}}
  end
end
