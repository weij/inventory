defmodule Inventory.ProductItemState do
  use GenStateMachine

  alias Inventory.ProductItem

  def start_link(pi = %ProductItem{state: current_state}, options \\ []) do
    default_state = Keyword.get(options, :default_state, :ready)
    state_timeout = Keyword.get(options, :state_timeout, 5_000)

    data = %{default_state: default_state, product_item: pi, state_timeout: state_timeout}

    GenStateMachine.start_link(__MODULE__, {current_state, data})
  end

  def get_state(pid) do
    :sys.get_state(pid)
  end
end
