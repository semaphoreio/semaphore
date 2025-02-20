defmodule Front.Support.Segment do
  def determine(billing_status) do
    if billing_status.plan == "paid" do
      last_charge = billing_status.last_charge_in_dollars

      cond do
        last_charge >= 1000 -> "gold"
        last_charge >= 300 -> "silver"
        last_charge >= 30 -> "iron"
        true -> "carbon"
      end
    end
  end
end
