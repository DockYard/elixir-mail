defmodule Pdf.ObjectCollection do
  @moduledoc false

  use GenServer
  import Pdf.Util.GenServerMacros

  alias Pdf.Object

  defmodule State do
    @moduledoc false
    defstruct size: 0, objects: %{}
  end

  def start_link, do: GenServer.start_link(__MODULE__, [])

  def init(_), do: {:ok, %State{}}

  defcall create_object(object, _from, %State{size: size, objects: objects} = state) do
    new_size = size + 1
    key = {:object, new_size, 0}
    {:reply, key, %{state | size: new_size, objects: Map.put(objects, key, object)}}
  end

  defcall get_object(key, _from, %State{objects: objects} = state) do
    object = Map.get(objects, key)
    {:reply, object, state}
  end

  defcall update_object(key, value, _from, %State{objects: objects} = state) do
    {:reply, :ok, %{state | objects: Map.put(objects, key, value)}}
  end

  defcall call(object_key, method, args, _from, %State{objects: objects} = state) do
    object = Map.get(objects, object_key)
    result = Kernel.apply(object.__struct__, method, [object | args])
    {:reply, object_key, %{state | objects: Map.put(objects, object_key, result)}}
  end

  defcall all(_from, %State{objects: objects} = state) do
    result =
      objects
      |> Enum.map(fn {{:object, number, _generation}, object} ->
        Object.new(number, object)
      end)

    {:reply, result, state}
  end
end
