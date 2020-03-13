defmodule Pdf.Fonts do
  use GenServer
  import Pdf.Util.GenServerMacros
  import Pdf.Utils

  alias Pdf.{Font, ExternalFont, ObjectCollection}

  defmodule State do
    defstruct last_id: 0, fonts: %{}, objects: nil
  end

  defmodule FontReference do
    defstruct name: nil, module: nil, object: nil
  end

  def start_link(objects), do: GenServer.start_link(__MODULE__, objects)

  def init(objects), do: {:ok, %State{objects: objects}}

  defcall get_font(name, opts, _from, state) do
    {state, ref} = lookup_font(state, name, opts)

    {:reply, ref, state}
  end

  defcall get_fonts(_from, %{fonts: fonts} = state) do
    {:reply, fonts, state}
  end

  defcall add_external_font(path, _from, state) do
    %{last_id: last_id, fonts: fonts, objects: objects} = state
    font_module = ExternalFont.load(path)

    unless fonts[font_module.name] do
      id = last_id + 1
      font_object = ObjectCollection.create_object(objects, nil)

      descriptor_id = descriptor_object = ObjectCollection.create_object(objects, nil)

      font_file = ObjectCollection.create_object(objects, font_module)

      font_dict = ExternalFont.font_dictionary(font_module, id, descriptor_id)
      font_descriptor_dict = ExternalFont.font_descriptor_dictionary(font_module, font_file)

      ObjectCollection.update_object(objects, descriptor_object, font_descriptor_dict)
      ObjectCollection.update_object(objects, font_object, font_dict)

      reference = %FontReference{
        name: n("F#{id}"),
        module: font_module,
        object: font_object
      }

      fonts = Map.put(fonts, font_module.name, reference)
      {:reply, reference, %{state | last_id: id, fonts: fonts}}
    else
      {:reply, :already_exists, state}
    end
  end

  defp lookup_font(state, name, opts) do
    case Font.lookup(name, opts) do
      nil ->
        lookup_font(state, name)

      font_module ->
        lookup_font(state, font_module)
    end
  end

  defp lookup_font(%{fonts: fonts} = state, name) when is_binary(name) do
    {state, fonts[name]}
  end

  defp lookup_font(%{fonts: fonts} = state, font_module) do
    case fonts[font_module.name] do
      nil -> load_font(state, font_module)
      font -> {state, font}
    end
  end

  defp load_font(%{fonts: fonts, last_id: last_id, objects: objects} = state, font_module) do
    id = last_id + 1
    font_object = ObjectCollection.create_object(objects, Font.to_dictionary(font_module, id))

    reference = %FontReference{
      name: n("F#{id}"),
      module: font_module,
      object: font_object
    }

    fonts = Map.put(fonts, font_module.name, reference)
    {%{state | last_id: id, fonts: fonts}, reference}
  end
end
