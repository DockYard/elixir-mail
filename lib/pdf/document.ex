defmodule Pdf.Document do
  defstruct objects: nil, info: nil, fonts: %{}, current: nil, pages: [], opts: [], images: %{}
  import Pdf.Utils

  alias Pdf.{
    Dictionary,
    Font,
    RefTable,
    Trailer,
    Array,
    ObjectCollection,
    Page,
    Paper,
    Image,
    ExternalFont
  }

  @header <<"%PDF-1.7\n%", 304, 345, 362, 345, 353, 247, 363, 240, 320, 304, 306, 10>>
  @header_size byte_size(@header)

  def new(opts \\ []) do
    {:ok, collection} = ObjectCollection.start_link()

    info =
      ObjectCollection.create_object(
        collection,
        Dictionary.new(%{"Creator" => "Elixir", "Producer" => "Elixir-PDF"})
      )

    document = %__MODULE__{objects: collection, info: info, opts: opts}
    add_page(document, Page.new(opts))
  end

  @info_map %{
    title: "Title",
    producer: "Producer",
    creator: "Creator",
    created: "CreationDate",
    modified: "ModDate",
    keywords: "Keywords",
    author: "Author",
    subject: "Subject"
  }

  def put_info(document, info_list) when is_list(info_list) do
    info = ObjectCollection.get_object(document.objects, document.info)

    info =
      info_list
      |> Enum.reduce(info, fn {key, value}, info ->
        case @info_map[key] do
          nil ->
            raise ArgumentError, "Invalid info key #{inspect(key)}"

          info_key ->
            Dictionary.put(info, info_key, value)
        end
      end)

    ObjectCollection.update_object(document.objects, document.info, info)
    document
  end

  @info_map
  |> Enum.each(fn {key, _value} ->
    def put_info(document, unquote(key), value), do: put_info(document, [{unquote(key), value}])
  end)

  # Pass-through functions that update the current page
  [
    {:set_fill_color, quote(do: [color])},
    {:set_stroke_color, quote(do: [color])},
    {:set_line_width, quote(do: [width])},
    {:rectangle, quote(do: [{x, y}, {w, h}])},
    {:line, quote(do: [{x, y}, {x2, y2}])},
    {:move_to, quote(do: [{x, y}])},
    {:line_append, quote(do: [{x, y}])},
    {:text_at, quote(do: [{x, y}, text, opts])},
    {:text_wrap, quote(do: [{x, y}, {w, h}, text, opts])},
    {:text_lines, quote(do: [{x, y}, lines, opts])},
    {:stroke, []}
  ]
  |> Enum.map(fn {func_name, args} ->
    def unquote(func_name)(%__MODULE__{current: page} = document, unquote_splicing(args)) do
      page = Page.unquote(func_name)(page, unquote_splicing(args))
      %{document | current: page}
    end
  end)

  def set_font(%__MODULE__{current: page} = document, font_name, font_size) do
    document = add_font(document, font_name)
    page = Page.set_font(page, document, font_name, font_size)
    %{document | current: page}
  end

  def text_at(document, xy, text), do: text_at(document, xy, text, [])

  def text_wrap(document, xy, wh, text), do: text_wrap(document, xy, wh, text, [])

  def text_lines(document, xy, lines), do: text_lines(document, xy, lines, [])

  def add_image(%__MODULE__{current: page} = document, {x, y}, image_path) do
    document = create_image(document, image_path)
    image = document.images[image_path]
    %{document | current: Page.add_image(page, {x, y}, image)}
  end

  defp create_image(%{objects: objects, images: images} = document, image_path) do
    images =
      Map.put_new_lazy(images, image_path, fn ->
        image = Image.new(image_path)
        object = ObjectCollection.create_object(objects, image)
        name = n("I#{Kernel.map_size(images) + 1}")
        %{name: name, object: object, image: image}
      end)

    %{document | images: images}
  end

  defp add_font(document, name) do
    unless document.fonts[name] do
      font_module = Font.lookup(name)
      id = Kernel.map_size(document.fonts) + 1
      # I don't need to do this at this point, it can be done when exporting, like the pages
      font_object =
        ObjectCollection.create_object(document.objects, Font.to_dictionary(font_module, id))

      fonts =
        Map.put(document.fonts, name, %{name: n("F#{id}"), font: font_module, object: font_object})

      %{document | fonts: fonts}
    else
      document
    end
  end

  def add_external_font(document, path) do
    font = ExternalFont.load(path)
    name = font.metrics.name

    unless document.fonts[name] do
      id = Kernel.map_size(document.fonts) + 1
      font_object = ObjectCollection.create_object(document.objects, nil)

      descriptor_id = descriptor_object = ObjectCollection.create_object(document.objects, nil)

      font_file = ObjectCollection.create_object(document.objects, font)

      font_dict = ExternalFont.font_dictionary(font, id, descriptor_id)
      font_descriptor_dict = ExternalFont.font_descriptor_dictionary(font, font_file)

      ObjectCollection.update_object(document.objects, descriptor_object, font_descriptor_dict)
      ObjectCollection.update_object(document.objects, font_object, font_dict)

      fonts =
        Map.put(document.fonts, name, %{
          name: n("F#{id}"),
          font: font,
          object: font_object
        })

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
    proc_set = [n("PDF"), n("Text")]

    proc_set =
      if Kernel.map_size(document.images) > 0,
        do: [n("ImageB"), n("ImageC"), n("ImageI") | proc_set],
        else: proc_set

    resources =
      Dictionary.new(%{
        "Font" => font_dictionary(document.fonts),
        "ProcSet" => Array.new(proc_set)
      })

    resources =
      if Kernel.map_size(document.images) > 0 do
        Dictionary.put(resources, "XObject", xobject_dictionary(document.images))
      else
        resources
      end

    page_collection =
      Dictionary.new(%{
        "Type" => n("Pages"),
        "Count" => length(pages),
        "MediaBox" => Array.new(Paper.size(default_page_size(document))),
        "Resources" => resources
      })

    master_page = ObjectCollection.create_object(document.objects, page_collection)
    page_objects = pages_to_objects(document, pages, master_page)
    ObjectCollection.call(document.objects, master_page, :put, ["Kids", Array.new(page_objects)])

    catalogue =
      ObjectCollection.create_object(
        document.objects,
        Dictionary.new(%{"Type" => n("Catalog"), "Pages" => master_page})
      )

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
    |> Enum.map(fn page ->
      page_object = ObjectCollection.create_object(objects, page)

      dictionary =
        Dictionary.new(%{
          "Type" => n("Page"),
          "Parent" => parent,
          "Contents" => page_object
        })

      dictionary =
        if page.size != default_page_size(document) do
          Dictionary.put(dictionary, "MediaBox", Array.new(Paper.size(page.size)))
        else
          dictionary
        end

      ObjectCollection.create_object(objects, dictionary)
    end)
  end

  defp font_dictionary(fonts) do
    fonts
    |> Enum.reduce(%{}, fn {_name, %{name: name, object: reference}}, map ->
      Map.put(map, name, reference)
    end)
    |> Dictionary.new()
  end

  defp xobject_dictionary(images) do
    images
    |> Enum.reduce(%{}, fn {_name, %{name: name, object: reference}}, map ->
      Map.put(map, name, reference)
    end)
    |> Dictionary.new()
  end

  defp default_page_size(%__MODULE__{opts: opts}), do: Keyword.get(opts, :size, :a4)
end
