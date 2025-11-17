# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaLbfgspp.Storage.LbfgsppInstance do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "lbfgspp_instances" do
    field(:instance_key, :string)
    field(:params_json, :string)
    field(:dimension, :integer)
    field(:current_point_json, :string)
    field(:iterations, :integer)
    field(:gradient_norm, :float)
    field(:objective_value, :float)
    field(:status, :string)
    field(:created_at, :utc_datetime_usec)
    field(:updated_at, :utc_datetime_usec)
  end

  def changeset(lbfgspp_instance, attrs) do
    lbfgspp_instance
    |> cast(attrs, [
      :instance_key,
      :params_json,
      :dimension,
      :current_point_json,
      :iterations,
      :gradient_norm,
      :objective_value,
      :status
    ])
    |> validate_required([:instance_key, :params_json, :dimension])
    |> unique_constraint(:instance_key)
  end
end
