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

    assert :ready = ProductItemState.current_state(pid)

    assert {:ok, :locked} = ProductItemState.lock(pid, order)
    assert {:locked, %{current_order: ^order, product_item: %ProductItem{id: 3}}} = ProductItemState.get_state(pid)

    Process.sleep(1_001)

    assert {:ready, %{current_order: nil}} = ProductItemState.get_state(pid)
  end

  test "product item can transition from locked to purchased, and can't be locked after purchase", context do
    %{order: order, item: item} = context

    {:ok, pid} = ProductItemState.start_link(item, state_timeout: 200)

    assert :ready = ProductItemState.current_state(pid)
    assert {:ok, :locked} = ProductItemState.lock(pid, order)
    assert {:locked, %{current_order: ^order}} = ProductItemState.get_state(pid)

    # locked state remains until the timeout is triggered
    Process.sleep(100)
    assert {:locked, %{current_order: ^order}} = ProductItemState.get_state(pid)

    # state can transition from locked to purchased
    payment_compeleted_order = %{order | state: :payment_complete}
    assert {:ok, :purchased} = ProductItemState.purchase(pid, payment_compeleted_order)
    assert {:purchased, %{current_order: ^payment_compeleted_order}} = ProductItemState.get_state(pid)

    # product item state remains purchased after the timeout
    Process.sleep(300)
    assert {:purchased, %{current_order: _}} = ProductItemState.get_state(pid)

    # same order can't lock down the same item again. The state stays in purchased.
    assert {:error, {:no_transition, "from purchased to locked"}} = ProductItemState.lock(pid, order)

    # the state stays purchased while the state of product item is set to sold.
    Process.sleep(200)
    assert {:purchased, %{product_item: %ProductItem{state: :sold}}} = ProductItemState.get_state(pid)
  end
end
