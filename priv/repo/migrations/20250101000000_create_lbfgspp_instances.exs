# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaLbfgspp.Repo.Migrations.CreateLbfgsppInstances do
  use Ecto.Migration

  def change do
    create table(:lbfgspp_instances, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :instance_key, :string, null: false
      add :params_json, :text, null: false
      add :dimension, :integer, null: false
      add :current_point_json, :text
      add :iterations, :integer, default: 0
      add :gradient_norm, :float, default: 0.0
      add :objective_value, :float, default: 0.0
      add :status, :string
      add :created_at, :utc_datetime_usec, null: false
      add :updated_at, :utc_datetime_usec, null: false
    end

    create unique_index(:lbfgspp_instances, [:instance_key])
  end
end
