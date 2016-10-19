defmodule Pdf do
  defmodule State do
    @moduledoc false
    defstruct document: nil
  end

  use GenServer
  import Pdf.Util.GenServerMacros
  alias Pdf.Document

  def new(opts \\ []),
    do: GenServer.start_link(__MODULE__, opts)

  def open(opts \\ [], func) do
    {:ok, pdf} = new(opts)
    func.(pdf)
    delete(pdf)
    :ok
  end

  def delete(pdf),
    do: GenServer.stop(pdf)

  def init(_args) do
    {:ok, %State{document: Document.new}}
  end

  @doc """
  Sets the author in the PDF information section.
  """
  defcall set_author(author, _from, state),
    do: set_info(:author, author, state)

  @doc """
  Sets the creator in the PDF information section.
  """
  defcall set_creator(creator, _from, state),
    do: set_info(:creator, creator, state)

  @doc """
  Sets the keywords in the PDF information section.
  """
  defcall set_keywords(keywords, _from, state),
    do: set_info(:keywords, keywords, state)

  @doc """
  Sets the producer in the PDF information section.
  """
  defcall set_producer(producer, _from, state),
    do: set_info(:producer, producer, state)

  @doc """
  Sets the subject in the PDF information section.
  """
  defcall set_subject(subject, _from, state),
    do: set_info(:subject, subject, state)

  @doc """
  Sets the title in the PDF information section.
  """
  defcall set_title(title, _from, state),
    do: set_info(:title, title, state)

  defp set_info(key, value, %State{document: document} = state) do
    document = Document.put_info(document, key, value)
    {:reply, self, %{state | document: document}}
  end
end
