defmodule Inventory.Order do
  defstruct id: nil,
            customer_id: nil,
            state: :pending_for_payment
end
