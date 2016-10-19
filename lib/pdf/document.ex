defmodule Pdf.Document do
  defstruct objects: nil, info: nil, fonts: %{}, pages: []

  alias Pdf.{Dictionary,Font,RefTable,Trailer,Array,ObjectCollection}

  @header << "%PDF-1.7\n%", 304, 345, 362, 345, 353, 247, 363, 240, 320, 304, 306, 10 >>
  @header_size byte_size(@header)

  def new do
    {:ok, collection} = ObjectCollection.start_link
    info = ObjectCollection.create_object(collection, Dictionary.new)
    %__MODULE__{objects: collection, info: info}
  end

  [title: "Title", producer: "Producer", creator: "Creator", created: "CreationDate", modified: "ModDate", keywords: "Keywords", author: "Author", subject: "Subject"]
  |> Enum.each(fn({key, value}) ->
    def put_info(document, unquote(key), value),
      do: do_put_info(document, unquote(value), value)
  end)

  defp do_put_info(document, key, value),
    do: %{document | info: ObjectCollection.call(document.objects, document.info, :put, [key, value])}

  def put_font(document, name) do
    font_module = Font.lookup(name)
    id = Map.size(document.fonts) + 1
    font_object = ObjectCollection.create_object(document.objects, Font.to_dictionary(font_module, id))
    fonts = Map.put(document.fonts, name, %{id: id, font: font_module, object: font_object})
    %{document | fonts: fonts}
  end

  def add_page(document, page) do
    %{document | pages: [page | document.pages]}
  end

  def to_iolist(document) do
    page_collection = Dictionary.new(%{
      "Type" => "/Page",
      "Count" => length(document.pages),
      "MediaBox" => Array.new([0, 0, 595, 842]),
      "Resources" => Dictionary.new(%{
        "Font" => font_dictionary(document.fonts),
        "ProcSet" => Array.new(["/PDF", "/Text"])
      })
    })
    master_page = ObjectCollection.create_object(document.objects, page_collection)
    page_objects = pages_to_objects(document.objects, document.pages, master_page)
    ObjectCollection.call(document.objects, master_page, :put, ["Kids", Array.new(page_objects)])

    catalogue = ObjectCollection.create_object(document.objects, Dictionary.new(%{"Type" => "/Catalogue", "Pages" => master_page}))

    objects = ObjectCollection.all(document.objects)

    {ref_table, offset} = RefTable.to_iolist(objects, @header_size)
    Pdf.Export.to_iolist([
      @header,
      objects,
      ref_table,
      Trailer.new(objects, offset, catalogue, document.info)
    ])
  end

  defp pages_to_objects(objects, pages, parent) do
    pages
    |> Enum.map(fn(page) ->
      page_object = ObjectCollection.create_object(objects, page)
      ObjectCollection.create_object(objects,
        Dictionary.new(%{
          "Type" => "/Page",
          "Parent" => parent,
          "Contents" => page_object
        }))
    end)
  end

  defp font_dictionary(fonts) do
    fonts
    |> Enum.reduce(%{}, fn({_name, %{id: id, object: {:object, _, _, reference}}}, map) ->
      Map.put(map, "F#{id}", reference)
    end)
    |> Dictionary.new
  end
end
