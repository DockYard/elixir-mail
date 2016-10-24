defmodule Pdf.Document do
  defstruct objects: nil, info: nil, fonts: %{}, current: nil, pages: [], opts: [], images: %{}

  alias Pdf.{Dictionary,Font,RefTable,Trailer,Array,ObjectCollection,Page,Paper,Image}

  @header << "%PDF-1.7\n%", 304, 345, 362, 345, 353, 247, 363, 240, 320, 304, 306, 10 >>
  @header_size byte_size(@header)

  def new(opts \\ []) do
    {:ok, collection} = ObjectCollection.start_link
    info = ObjectCollection.create_object(collection, Dictionary.new(%{"Creator" => "Elixir", "Producer" => "Elixir-PDF"}))
    document = %__MODULE__{objects: collection, info: info, opts: opts}
    add_page(document, Page.new(opts))
  end

  [title: "Title", producer: "Producer", creator: "Creator", created: "CreationDate", modified: "ModDate", keywords: "Keywords", author: "Author", subject: "Subject"]
  |> Enum.each(fn({key, value}) ->
    def put_info(document, unquote(key), value),
      do: do_put_info(document, unquote(value), value)
  end)

  defp do_put_info(document, key, value),
    do: %{document | info: ObjectCollection.call(document.objects, document.info, :put, [key, value])}

  def set_font(%__MODULE__{current: page} = document, font_name, font_size) do
    document = add_font(document, font_name)
    page = Page.set_font(page, document, font_name, font_size)
    %{document | current: page}
  end

  def text_at(%__MODULE__{current: page} = document, {x, y}, text) do
    %{document | current: Page.text_at(page, {x, y}, text)}
  end

  def text_lines(%__MODULE__{current: page} = document, {x, y}, lines) do
    %{document | current: Page.text_lines(page, {x, y}, lines)}
  end

  def add_image(%__MODULE__{current: page} = document, {x, y}, image_path) do
    document = create_image(document, image_path)
    image = document.images[image_path]
    %{document | current: Page.add_image(page, {x, y}, image)}
  end

  defp create_image(%{objects: objects, images: images} = document, image_path) do
    images = Map.put_new_lazy(images, image_path, fn ->
      image = Image.new(image_path)
      object = ObjectCollection.create_object(objects, image)
      name = "I#{Map.size(images) + 1}"
      %{name: name, object: object, image: image}
    end)
    %{document | images: images}
  end

  def add_font(document, name) do
    unless document.fonts[name] do
      font_module = Font.lookup(name)
      id = Map.size(document.fonts) + 1
      # I don't need to do this at this point, it can be done when exporting, like the pages
      font_object = ObjectCollection.create_object(document.objects, Font.to_dictionary(font_module, id))
      fonts = Map.put(document.fonts, name, %{id: id, font: font_module, object: font_object})
      %{document | fonts: fonts}
    else
      document
    end
  end

  def add_page(%__MODULE__{current: nil} = document, new_page),
    do: %{document | current: new_page}
  def add_page(%__MODULE__{current: current_page, pages: pages} = document, new_page),
    do: add_page(%{document | current: nil, pages: [current_page | pages]}, new_page)

  def to_iolist(document) do
    pages = Enum.reverse([document.current | document.pages])
    proc_set = ["/PDF", "/Text"]
    proc_set = if Map.size(document.images) > 0, do: ["/ImageB", "/ImageC", "/ImageI" | proc_set], else: proc_set
    resources = Dictionary.new(%{
      "Font" => font_dictionary(document.fonts),
      "ProcSet" => Array.new(proc_set)
    })
    resources = if Map.size(document.fonts) do
      Dictionary.put(resources, "Font", font_dictionary(document.fonts))
    else
      resources
    end
    resources = if Map.size(document.images) do
      Dictionary.put(resources, "XObject", xobject_dictionary(document.images))
    else
      resources
    end
    page_collection = Dictionary.new(%{
      "Type" => "/Page",
      "Count" => length(pages),
      "MediaBox" => Array.new(Paper.size(default_page_size(document))),
      "Resources" => resources
    })
    master_page = ObjectCollection.create_object(document.objects, page_collection)
    page_objects = pages_to_objects(document, pages, master_page)
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

  defp pages_to_objects(%__MODULE__{objects: objects} = document, pages, parent) do
    pages
    |> Enum.map(fn(page) ->
      page_object = ObjectCollection.create_object(objects, page)
      dictionary =
        Dictionary.new(%{
          "Type" => "/Page",
          "Parent" => parent,
          "Contents" => page_object
        })

      dictionary = if page.size != default_page_size(document) do
        Dictionary.put(dictionary, "MediaBox", Array.new(Paper.size(page.size)))
      else
        dictionary
      end

      ObjectCollection.create_object(objects, dictionary)
    end)
  end

  defp font_dictionary(fonts) do
    fonts
    |> Enum.reduce(%{}, fn({_name, %{id: id, object: {:object, _, _, reference}}}, map) ->
      Map.put(map, "F#{id}", reference)
    end)
    |> Dictionary.new
  end

  defp xobject_dictionary(images) do
    images
    |> Enum.reduce(%{}, fn({_name, %{name: name, object: {:object, _, _, reference}}}, map) ->
      Map.put(map, name, reference)
    end)
    |> Dictionary.new
  end

  defp default_page_size(%__MODULE__{opts: opts}),
    do: Keyword.get(opts, :size, :a4)
end
