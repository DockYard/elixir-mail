defmodule Pdf.SizeTest do
  use ExUnit.Case, async: true

  alias Pdf.Size

  describe "size_of/1 for BitString" do
    test "it returns the length of the string" do
      assert Size.size_of("string") == 6
    end
  end

  describe "size_of/1 for Integer" do
    test "it returns the number of digits in the number" do
      assert Size.size_of(13) == 2
      assert Size.size_of(420) == 3
      assert Size.size_of(999_999) == 6
    end
  end

  describe "size_of/1 for Float" do
    test "it returns the number of digits in the number" do
      assert Size.size_of(13.3) == 4
      assert Size.size_of(420.0) == 5
      assert Size.size_of(999_999.01) == 9
      assert Size.size_of(10.934000000000001) == 6
    end
  end

  describe "size_of/1 for Date" do
    test "it returns the length of the encoded date" do
      assert Size.size_of(~D"2018-05-22") == 12
    end
  end

  describe "size_of/1 for DateTime" do
    test "it returns the length of the encoded datetime with positive timezone offset" do
      datetime = %DateTime{
        year: 2018,
        month: 5,
        day: 22,
        hour: 17,
        minute: 2,
        second: 0,
        utc_offset: 7200,
        time_zone: "Africa/Johannesburg",
        zone_abbr: "SAST",
        std_offset: 0
      }

      assert Size.size_of(datetime) == 24
    end

    test "it returns the length of the encoded datetime with negative timezone offset" do
      datetime = %DateTime{
        year: 2018,
        month: 5,
        day: 22,
        hour: 17,
        minute: 2,
        second: 0,
        utc_offset: -14400,
        time_zone: "Eastern Daylight Time",
        zone_abbr: "EDT",
        std_offset: 0
      }

      assert Size.size_of(datetime) == 24
    end

    test "it returns the length of the encoded datetime in UTC" do
      datetime = %DateTime{
        year: 2018,
        month: 5,
        day: 22,
        hour: 17,
        minute: 2,
        second: 0,
        utc_offset: 0,
        time_zone: "UTC",
        zone_abbr: "UTC",
        std_offset: 0
      }

      assert Size.size_of(datetime) == 19
    end
  end

  describe "size_of/1 for List" do
    test "it returns the length of each of the list elements added together" do
      assert Size.size_of(["string", 13]) == 8

      list = ["a long string", 123_456, ~D"2018-05-22", {:name, "Name"}]
      assert Size.size_of(list) == Enum.map(list, &Size.size_of/1) |> Enum.reduce(&+/2)
    end

    test "string in list" do
      assert Size.size_of(["BT"]) == 2
    end
  end

  describe "size_of/1 for Tuple" do
    test "it returns the correct length for a name field" do
      assert Size.size_of({:name, "Name"}) == 5
      assert Size.size_of({:name, "LongName"}) == 9
    end

    test "it returns the correct length for a string field" do
      assert Size.size_of({:string, "string"}) == 8
      assert Size.size_of({:string, "a long string"}) == 15
    end

    test "it returns the correct length for an object reference" do
      assert Size.size_of({:object, 1, 0}) == 6
      assert Size.size_of({:object, 1, 10}) == 7
      assert Size.size_of({:object, 10, 0}) == 7
      assert Size.size_of({:object, 10, 11}) == 8
    end

    test "it returns the correct length for a command" do
      assert Size.size_of({:command, "BT"}) == 2
      # /F1 12 Tf
      command = {:command, [{:name, "F1"}, 12, "Tf"]}
      assert Size.size_of(command) == 9
    end
  end
end
