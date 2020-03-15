defmodule Inventory.ProductItemState do
  use GenStateMachine

  alias Inventory.{ProductItem, Order}

  def start_link(pi = %ProductItem{state: current_state}, options \\ []) do
    default_state = Keyword.get(options, :default_state, :ready)
    state_timeout = Keyword.get(options, :state_timeout, 5_000)

    data = %{default_state: default_state, product_item: pi, state_timeout: state_timeout}

    GenStateMachine.start_link(__MODULE__, {current_state, data})
  end

  def get_state(pid) do
    :sys.get_state(pid)
  end

  def lock(pid, order = %Order{}) do
    GenStateMachine.call(pid, {:lock, order})
  end

  # Server Callbacks

  @doc """
  Transition from `ready` to `locked` before pulling from warehouse location.
  A timeout is set to reset the state.
  """
  def handle_event({:call, from}, {:lock, order}, :ready, data) do
    %{state_timeout: state_timeout} = data
    data = Map.put(data, :current_order, order)

    {:next_state, :locked, data,
     [
       {:reply, from, {:ok, :locked}},
       {:state_timeout, state_timeout, :lock_timeout},
     ]}
  end

  def handle_event(:state_timeout, :lock_timeout, :locked, data) do
    %{default_state: default_state} = data
    data = Map.put(data, :current_order, nil)

    {:next_state, default_state, data}
  end

end
