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

  test "lock down a product item for a time interval, when timeout resets state", context do
    %{order: order, item: item} = context

    {:ok, pid} = ProductItemState.start_link(item, state_timeout: 1_000)

    assert ProductItemState.lock(pid, order) == {:ok, :locked}
    assert {:locked, %{current_order: _order, product_item: %ProductItem{id: 3}}} = ProductItemState.get_state(pid)

    Process.sleep(1_001)

    assert {:ready, %{current_order: nil}} = ProductItemState.get_state(pid)
  end
end
