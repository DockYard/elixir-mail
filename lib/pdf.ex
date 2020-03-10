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

  defcall set_font(font_name, font_size, _from, %State{document: document} = state) do
    document = Document.set_font(document, font_name, font_size)
    {:reply, self(), %{state | document: document}}
  end

  defcall add_font(path, _from, %State{document: document} = state) do
    document = Document.add_external_font(document, path)
    {:reply, self(), %{state | document: document}}
  end

  defcall text_at({x, y}, text, _from, %State{document: document} = state) do
    document = Document.text_at(document, {x, y}, text)
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
