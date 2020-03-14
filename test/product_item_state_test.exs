defmodule Inventory.ProductItemStateTest do
  use ExUnit.Case

  alias Inventory.{Order, ProductItem, ProductItemState}

  setup do
    order = %Order{id: 1, customer_id: 53}
    item = %ProductItem{id: 3, barcode: 12345, product: "t-shirt", state: :ready}

    {:ok, %{order: order, item: item}}
  end

  test "process hold all state", %{item: item}= _context do
    {:ok, pid} = ProductItemState.start_link(item)
    all_state = ProductItemState.get_state(pid)

    assert all_state == {:ready, %{default_state: :ready, state_timeout: 5_000, product_item: item}}
  end

  test "transition from ready to locked", %{item: item, order: order} do
    {:ok, pid} = ProductItemState.start_link(item)
    assert ProductItemState.lock(pid, order) == {:ok, :locked}
  end

end
