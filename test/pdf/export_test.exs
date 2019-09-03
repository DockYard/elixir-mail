defmodule Pdf.ExportTest do
  use ExUnit.Case, async: true

  alias Pdf.Export

  describe "to_iolist/1 for BitString" do
    test "it returns the string untouched" do
      assert Export.to_iolist("string") == "string"
    end
  end

  describe "to_iolist/1 for Integer" do
    test "it returns the number as a binary" do
      assert Export.to_iolist(13) == "13"
      assert Export.to_iolist(42) == "42"
    end
  end

  describe "to_iolist/1 for Float" do
    test "it returns the number as a binary" do
      assert Export.to_iolist(13.2) == "13.2"
      assert Export.to_iolist(420.720) == "420.72"
    end
  end

  describe "to_iolist/1 for Date" do
    test "it returns the date correctly encoded with a positive timezone offset" do
      assert Export.to_iolist(~D"2018-05-22") |> IO.iodata_to_binary() == "(D:20180522)"
    end
  end

  describe "to_iolist/1 for DateTime" do
    test "it returns the date correctly encoded with a positive timezone offset" do
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

      assert Export.to_iolist(datetime) |> IO.iodata_to_binary() == "(D:20180522170200+02'00)"
    end

    test "it returns the date correctly encoded with a negative timezone offset" do
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

      assert Export.to_iolist(datetime) |> IO.iodata_to_binary() == "(D:20180522170200-04'00)"
    end

    test "it returns the date correctly encoded for UTC time" do
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

      assert Export.to_iolist(datetime) |> IO.iodata_to_binary() == "(D:20180522170200Z)"
    end
  end

  describe "to_iolist/1 for List" do
    test "it returns the list with each value run through Export" do
      assert Export.to_iolist(["string", 13]) == ["string", "13"]
    end
  end

  describe "to_iolist/1 for Tuple" do
    test "it returns the correct length for a name field" do
      assert Export.to_iolist({:name, "Name"}) |> IO.iodata_to_binary() == "/Name"
      assert Export.to_iolist({:name, "LongName"}) |> IO.iodata_to_binary() == "/LongName"
    end

    test "it returns the correct length for a string field" do
      assert Export.to_iolist({:string, "string"}) |> IO.iodata_to_binary() == "(string)"

      assert Export.to_iolist({:string, "a long string"}) |> IO.iodata_to_binary() ==
               "(a long string)"
    end

    test "it returns the correct length for an object reference" do
      assert Export.to_iolist({:object, 1, 0}) |> IO.iodata_to_binary() == "1 0 R"
      assert Export.to_iolist({:object, 1, 10}) |> IO.iodata_to_binary() == "1 10 R"
      assert Export.to_iolist({:object, 10, 0}) |> IO.iodata_to_binary() == "10 0 R"
      assert Export.to_iolist({:object, 10, 11}) |> IO.iodata_to_binary() == "10 11 R"
    end

    test "it returns the correct length for a command" do
      assert Export.to_iolist({:command, "BT"}) == "BT"

      assert Export.to_iolist({:command, [{:name, "F1"}, 12, "Tf"]}) == [
               {:name, "F1"},
               [[" ", 12], [" ", "Tf"]]
             ]
    end
  end
end
