defmodule Pdf.ObjectCollectionTest do
  use ExUnit.Case, async: true

  alias Pdf.{Dictionary,ObjectCollection}

  test "adding an object to the collection" do
    {:ok, collection} = ObjectCollection.start_link
    dictionary = Dictionary.new
    object = ObjectCollection.create_object(collection, dictionary)
    assert object == {:object, 1, 0}
  end
end
