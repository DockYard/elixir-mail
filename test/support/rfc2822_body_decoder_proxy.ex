defmodule Mail.RFC2822BodyDecoderProxy do
  use GenServer

  @behaviour Mail.Parsers.RFC2822.BodyDecoder

  @strict_impl Mail.Parsers.RFC2822.BodyDecoder.Strict
  @permissive_impl Mail.Parsers.RFC2822.BodyDecoder.Permissive

  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  def strict_impl, do: GenServer.call(__MODULE__, {:set_impl, @strict_impl})

  def permissive_impl, do: GenServer.call(__MODULE__, {:set_impl, @permissive_impl})

  @impl Mail.Parsers.RFC2822.BodyDecoder
  def decode(body, message) do
    case GenServer.call(__MODULE__, {:decode, body, message}) do
      {:ok, decoded} ->
        decoded

      {:error, :pid_not_found} ->
        raise RuntimeError, "You should set an impl module for decoder proxy"
    end
  end

  @impl GenServer
  def init(opts), do: {:ok, {Keyword.get(opts, :default_impl), %{}}}

  @impl GenServer
  def handle_call({:set_impl, impl}, {test_pid, _tag}, {default_impl, pid_map}) do
    Process.monitor(test_pid)

    {:reply, :ok, {default_impl, Map.put(pid_map, test_pid, impl)}}
  end

  def handle_call({:decode, body, message}, {test_pid, _tag}, {nil, pid_map} = state) do
    case Map.get(pid_map, test_pid) do
      nil ->
        {:reply, {:error, :pid_not_found}, state}

      impl ->
        {:reply, {:ok, impl.decode(body, message)}, state}
    end
  end

  def handle_call({:decode, body, message}, {test_pid, _tag}, {default_impl, pid_map} = state) do
    case Map.get(pid_map, test_pid) do
      nil ->
        {:reply, {:ok, default_impl.decode(body, message)}, state}

      impl ->
        {:reply, {:ok, impl.decode(body, message)}, state}
    end
  end

  @impl GenServer
  def handle_info({:DOWN, _ref, :process, test_pid, _reason}, {default_impl, pid_map}),
    do: {:noreply, {default_impl, Map.delete(pid_map, test_pid)}}
end
