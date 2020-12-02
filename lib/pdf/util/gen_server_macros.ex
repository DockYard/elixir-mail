defmodule Pdf.Util.GenServerMacros do
  @moduledoc false
  @doc false
  defmacro defcall({name, _, args}, opts) do
    [state, from | args] = Enum.reverse(args)
    args = Enum.reverse(args)

    quote do
      def unquote(name)(pid, unquote_splicing(args)) do
        case GenServer.call(pid, {unquote(name), unquote_splicing(args)}, 120_000) do
          {:raise, exception} -> raise exception
          result -> result
        end
      end

      defp unquote(:"do_#{name}")(unquote_splicing(args), unquote(from), unquote(state)) do
        try do
          unquote(opts[:do])
        rescue
          exception -> {:reply, {:raise, exception}, unquote(state)}
        end
      end

      def handle_call({unquote(name), unquote_splicing(args)}, from, state) do
        unquote(:"do_#{name}")(unquote_splicing(args), from, state)
      end
    end
  end
end
