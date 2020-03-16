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

  def current_state(pid) do
    GenStateMachine.call(pid, :current_state)
  end

  def lock(pid, order = %Order{}) do
    GenStateMachine.call(pid, {:lock, order})
  end

  def purchase(pid, order = %Order{state: :payment_complete}) do
    GenStateMachine.call(pid, {:purchase, order})
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

  @doc """
  Can't transition from `purchased` to `locked`.
  """
  def handle_event({:call, from}, {:lock, _order}, :purchased, _data) do
    reason = {:no_transition, "from purchased to locked"}

    {:keep_state_and_data, [{:reply, from, {:error, reason}}]}
  end

  def handle_event({:call, from}, {:purchase, order}, :locked, data) do
    %{current_order: current_order, product_item: item} = data

    case order.customer_id == current_order.customer_id do
      true ->
        data = %{data | current_order: order, product_item: Map.put(item, :state, :sold)}

        {:next_state, :purchased, data,
        [
          {:reply, from, {:ok, :purchased}}
        ]}
      _ ->
        reason = "no transition"

        {:keep_state_and_data, {:reply, from, {:error, reason}}}
    end
  end

  def handle_event({:call, from}, :current_state, current_state, _) do
    {:keep_state_and_data, [{:reply, from, current_state}]}
  end

  def handle_event(:state_timeout, :lock_timeout, :locked, data) do
    %{default_state: default_state} = data
    data = Map.put(data, :current_order, nil)

    {:next_state, default_state, data}
  end

end
