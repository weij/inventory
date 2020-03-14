defmodule InventoryTest do
  use ExUnit.Case
  doctest Inventory

  test "greets the world" do
    assert Inventory.hello() == :world
  end
end
