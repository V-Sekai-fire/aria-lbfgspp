# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaLbfgspp.TestFixtures.ParamSpaces do
  @moduledoc """
  Test fixtures for LBFGS++ parameter spaces.

  Provides common parameter space configurations for testing.
  """

  @doc """
  Returns a simple LinearSpace parameter space for testing.
  """
  def linear_space_example do
    [
      %{
        "name" => "learning_rate",
        "space_type" => "LinearSpace",
        "min" => 0.001,
        "max" => 0.1,
        "scale" => 0.01,
        "search_center" => 0.01
      }
    ]
  end

  @doc """
  Returns a LogSpace parameter space for testing (common for learning rates).
  """
  def log_space_example do
    [
      %{
        "name" => "learning_rate",
        "space_type" => "LogSpace",
        "min" => 0.0001,
        "max" => 0.1,
        "scale" => 1.0,
        "search_center" => 0.01
      }
    ]
  end

  @doc """
  Returns a LogitSpace parameter space for testing (for values between 0 and 1).
  """
  def logit_space_example do
    [
      %{
        "name" => "momentum",
        "space_type" => "LogitSpace",
        "search_center" => 0.9
      }
    ]
  end

  @doc """
  Returns a multi-parameter space with different space types.
  """
  def multi_param_space do
    [
      %{
        "name" => "learning_rate",
        "space_type" => "LogSpace",
        "min" => 0.0001,
        "max" => 0.1,
        "scale" => 1.0,
        "search_center" => 0.01
      },
      %{
        "name" => "batch_size",
        "space_type" => "LinearSpace",
        "min" => 16,
        "max" => 128,
        "scale" => 16,
        "is_integer" => true,
        "search_center" => 32
      },
      %{
        "name" => "momentum",
        "space_type" => "LogitSpace",
        "search_center" => 0.9
      }
    ]
  end

  @doc """
  Returns an integer parameter space (for epochs, batch size, etc.).
  """
  def integer_param_space do
    [
      %{
        "name" => "epochs",
        "space_type" => "LogSpace",
        "min" => 2,
        "max" => 512,
        "scale" => 1.0,
        "is_integer" => true,
        "search_center" => 10
      }
    ]
  end

  @doc """
  Returns a minimal parameter space for quick tests.
  """
  def minimal_param_space do
    [
      %{
        "name" => "x",
        "space_type" => "LinearSpace",
        "min" => 0.0,
        "max" => 1.0,
        "scale" => 0.1,
        "search_center" => 0.5
      }
    ]
  end

  @doc """
  Returns parameter spaces for neural network hyperparameter optimization scenario.
  Includes: learning_rate, batch_size, dropout_rate, weight_decay
  """
  def neural_network_hyperparams do
    [
      %{
        "name" => "learning_rate",
        "space_type" => "LogSpace",
        "min" => 0.0001,
        "max" => 0.1,
        "scale" => 1.0,
        "search_center" => 0.001
      },
      %{
        "name" => "batch_size",
        "space_type" => "LinearSpace",
        "min" => 16,
        "max" => 256,
        "scale" => 16,
        "is_integer" => true,
        "search_center" => 64
      },
      %{
        "name" => "dropout_rate",
        "space_type" => "LinearSpace",
        "min" => 0.0,
        "max" => 0.8,
        "scale" => 0.1,
        "search_center" => 0.5
      },
      %{
        "name" => "weight_decay",
        "space_type" => "LogSpace",
        "min" => 1.0e-6,
        "max" => 1.0e-2,
        "scale" => 1.0,
        "search_center" => 1.0e-4
      }
    ]
  end

  @doc """
  Returns parameter spaces for manufacturing process optimization scenario.
  Includes: temperature, pressure, flow_rate, reaction_time
  """
  def manufacturing_process_params do
    [
      %{
        "name" => "temperature",
        "space_type" => "LinearSpace",
        "min" => 100.0,
        "max" => 300.0,
        "scale" => 10.0,
        "search_center" => 200.0
      },
      %{
        "name" => "pressure",
        "space_type" => "LinearSpace",
        "min" => 1.0,
        "max" => 10.0,
        "scale" => 0.5,
        "search_center" => 5.0
      },
      %{
        "name" => "flow_rate",
        "space_type" => "LogSpace",
        "min" => 0.1,
        "max" => 10.0,
        "scale" => 1.0,
        "search_center" => 1.0
      },
      %{
        "name" => "reaction_time",
        "space_type" => "LinearSpace",
        "min" => 5.0,
        "max" => 60.0,
        "scale" => 5.0,
        "search_center" => 30.0
      }
    ]
  end

  @doc """
  Returns parameter spaces for supply chain inventory optimization scenario.
  Includes: reorder_point, order_quantity, safety_stock, review_period
  """
  def inventory_management_params do
    [
      %{
        "name" => "reorder_point",
        "space_type" => "LinearSpace",
        "min" => 10.0,
        "max" => 500.0,
        "scale" => 10.0,
        "search_center" => 100.0
      },
      %{
        "name" => "order_quantity",
        "space_type" => "LinearSpace",
        "min" => 50.0,
        "max" => 1000.0,
        "scale" => 50.0,
        "search_center" => 200.0
      },
      %{
        "name" => "safety_stock",
        "space_type" => "LinearSpace",
        "min" => 5.0,
        "max" => 100.0,
        "scale" => 5.0,
        "search_center" => 25.0
      },
      %{
        "name" => "review_period",
        "space_type" => "LinearSpace",
        "min" => 1.0,
        "max" => 30.0,
        "scale" => 1.0,
        "is_integer" => true,
        "search_center" => 7.0
      }
    ]
  end

  @doc """
  Returns parameter spaces for Gaussian process optimization test (2D).
  Ground truth optimal: [0.5, 1.5]
  """
  def gaussian_process_2d_params do
    [
      %{
        "name" => "x1",
        "space_type" => "LinearSpace",
        "min" => -2.0,
        "max" => 3.0,
        "scale" => 0.5,
        "search_center" => 0.0
      },
      %{
        "name" => "x2",
        "space_type" => "LinearSpace",
        "min" => -1.0,
        "max" => 4.0,
        "scale" => 0.5,
        "search_center" => 1.0
      }
    ]
  end

  @doc """
  Returns parameter spaces for Gaussian process optimization test (3D).
  Ground truth optimal: [1.0, 2.0, 0.5]
  """
  def gaussian_process_3d_params do
    [
      %{
        "name" => "x1",
        "space_type" => "LinearSpace",
        "min" => -1.0,
        "max" => 3.0,
        "scale" => 0.5,
        "search_center" => 0.5
      },
      %{
        "name" => "x2",
        "space_type" => "LinearSpace",
        "min" => 0.0,
        "max" => 4.0,
        "scale" => 0.5,
        "search_center" => 1.5
      },
      %{
        "name" => "x3",
        "space_type" => "LinearSpace",
        "min" => -0.5,
        "max" => 1.5,
        "scale" => 0.2,
        "search_center" => 0.3
      }
    ]
  end
end
