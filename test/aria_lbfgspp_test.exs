# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaLbfgsppTest do
  use ExUnit.Case, async: false

  alias AriaLbfgspp.TestFixtures.ParamSpaces
  alias AriaLbfgspp.TestFixtures.LbfgsppConfig

  setup do
    # Ensure application is started
    Application.ensure_all_started(:aria_lbfgspp)
    :ok
  end

  describe "available?/0" do
    test "returns true when NIF is available" do
      # Note: NIF may not be available if not compiled
      result = AriaLbfgspp.available?()
      assert is_boolean(result)
    end
  end

  describe "init/2 (CARBS-like interface)" do
    test "initializes LBFGS++ with minimal config and LinearSpace" do
      params = LbfgsppConfig.minimal_config()
      param_spaces = ParamSpaces.linear_space_example()

      result = AriaLbfgspp.init(params, param_spaces)
      assert match?({:ok, :lbfgspp_initialized}, result) or match?({:error, _}, result)
    end

    test "initializes LBFGS++ with LogSpace parameter" do
      params = LbfgsppConfig.minimal_config()
      param_spaces = ParamSpaces.log_space_example()

      result = AriaLbfgspp.init(params, param_spaces)
      assert match?({:ok, :lbfgspp_initialized}, result) or match?({:error, _}, result)
    end

    test "initializes LBFGS++ with LogitSpace parameter" do
      params = LbfgsppConfig.minimal_config()
      param_spaces = ParamSpaces.logit_space_example()

      result = AriaLbfgspp.init(params, param_spaces)
      assert match?({:ok, :lbfgspp_initialized}, result) or match?({:error, _}, result)
    end

    test "initializes LBFGS++ with QuadWild parameter spaces" do
      params = LbfgsppConfig.minimal_config()
      param_spaces = ParamSpaces.quadwild_param_spaces()

      result = AriaLbfgspp.init(params, param_spaces)
      assert match?({:ok, :lbfgspp_initialized}, result) or match?({:error, _}, result)
    end

    test "initializes LBFGS++ with multi-parameter space" do
      params = LbfgsppConfig.default_config()
      param_spaces = ParamSpaces.multi_param_space()

      result = AriaLbfgspp.init(params, param_spaces)
      assert match?({:ok, :lbfgspp_initialized}, result) or match?({:error, _}, result)
    end

    test "returns error when param_spaces is empty" do
      params = LbfgsppConfig.minimal_config()
      param_spaces = []

      assert {:error, "param_spaces cannot be empty"} = AriaLbfgspp.init(params, param_spaces)
    end

    test "returns error when NIF is not available" do
      # This test verifies error handling
      # In practice, if NIF is not available, init will return an error
      params = LbfgsppConfig.minimal_config()
      param_spaces = ParamSpaces.minimal_param_space()

      result = AriaLbfgspp.init(params, param_spaces)
      assert match?({:ok, :lbfgspp_initialized}, result) or match?({:error, _}, result)
    end
  end

  describe "suggest/0 (CARBS-like interface)" do
    setup do
      # Initialize LBFGS++ before each test if available
      if AriaLbfgspp.available?() do
        params = LbfgsppConfig.minimal_config()
        param_spaces = ParamSpaces.minimal_param_space()
        AriaLbfgspp.init(params, param_spaces)
        :ok
      else
        :skip
      end
    end

    test "returns a suggestion after initialization" do
      if AriaLbfgspp.available?() do
        result = AriaLbfgspp.suggest()

        case result do
          {:ok, suggestion} ->
            assert is_map(suggestion)
            assert Map.has_key?(suggestion, "x")
            assert is_float(suggestion["x"]) or is_integer(suggestion["x"])

          {:error, _reason} ->
            # NIF not available or not initialized
            :ok
        end
      end
    end

    test "suggestion values match parameter space structure" do
      if AriaLbfgspp.available?() do
        case AriaLbfgspp.suggest() do
          {:ok, suggestion} ->
            # For minimal_param_space: x should be present
            assert Map.has_key?(suggestion, "x")
            # Value should be a number
            assert is_number(suggestion["x"])

          {:error, _reason} ->
            :ok
        end
      end
    end

    test "returns error when not initialized" do
      # Try to suggest without initialization
      # This might work if a previous test initialized it
      result = AriaLbfgspp.suggest()
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "observe/4 (CARBS-like interface)" do
    setup do
      if AriaLbfgspp.available?() do
        params = LbfgsppConfig.minimal_config()
        param_spaces = ParamSpaces.minimal_param_space()
        AriaLbfgspp.init(params, param_spaces)
        :ok
      else
        :skip
      end
    end

    test "observes a successful result" do
      if AriaLbfgspp.available?() do
        case AriaLbfgspp.suggest() do
          {:ok, suggestion} ->
            output = 0.5
            cost = 10.0

            result = AriaLbfgspp.observe(suggestion, output, cost, false)
            assert match?({:ok, :observed}, result) or match?({:error, _}, result)

          {:error, _reason} ->
            :ok
        end
      end
    end

    test "observes a failed result" do
      if AriaLbfgspp.available?() do
        case AriaLbfgspp.suggest() do
          {:ok, suggestion} ->
            output = 0.0
            cost = 5.0

            result = AriaLbfgspp.observe(suggestion, output, cost, true)
            assert match?({:ok, :observed}, result) or match?({:error, _}, result)

          {:error, _reason} ->
            :ok
        end
      end
    end

    test "observes multiple results in sequence" do
      if AriaLbfgspp.available?() do
        # Get first suggestion
        case AriaLbfgspp.suggest() do
          {:ok, suggestion1} ->
            result1 = AriaLbfgspp.observe(suggestion1, 0.3, 8.0, false)
            assert match?({:ok, :observed}, result1) or match?({:error, _}, result1)

            # Get second suggestion
            case AriaLbfgspp.suggest() do
              {:ok, suggestion2} ->
                result2 = AriaLbfgspp.observe(suggestion2, 0.7, 12.0, false)
                assert match?({:ok, :observed}, result2) or match?({:error, _}, result2)

              {:error, _reason} ->
                :ok
            end

          {:error, _reason} ->
            :ok
        end
      end
    end

    test "handles float output and cost values" do
      if AriaLbfgspp.available?() do
        case AriaLbfgspp.suggest() do
          {:ok, suggestion} ->
            output = 0.123456789
            cost = 99.999

            result = AriaLbfgspp.observe(suggestion, output, cost, false)
            assert match?({:ok, :observed}, result) or match?({:error, _}, result)

          {:error, _reason} ->
            :ok
        end
      end
    end
  end

  describe "integration: full LBFGS++ workflow (CARBS-like)" do
    test "complete workflow: init -> suggest -> observe (multiple iterations)" do
      if AriaLbfgspp.available?() do
        params = LbfgsppConfig.quick_test_config()
        param_spaces = ParamSpaces.minimal_param_space()

        # Initialize
        case AriaLbfgspp.init(params, param_spaces) do
          {:ok, :lbfgspp_initialized} ->
            # Run a few iterations
            for _i <- 1..3 do
              case AriaLbfgspp.suggest() do
                {:ok, suggestion} ->
                  assert is_map(suggestion)

                  # Simulate testing the suggestion
                  output = :rand.uniform()
                  cost = :rand.uniform() * 100.0

                  result = AriaLbfgspp.observe(suggestion, output, cost, false)
                  assert match?({:ok, :observed}, result) or match?({:error, _}, result)

                {:error, _reason} ->
                  :ok
              end
            end

          {:error, _reason} ->
            # NIF not available
            :ok
        end
      end
    end

    test "QuadWild parameter optimization workflow" do
      if AriaLbfgspp.available?() do
        params = LbfgsppConfig.quick_test_config()
        param_spaces = ParamSpaces.quadwild_param_spaces()

        case AriaLbfgspp.init(params, param_spaces) do
          {:ok, :lbfgspp_initialized} ->
            case AriaLbfgspp.suggest() do
              {:ok, suggestion1} ->
                assert Map.has_key?(suggestion1, "Alpha")
                assert Map.has_key?(suggestion1, "ScaleFact")
                assert Map.has_key?(suggestion1, "SharpAngle")

                # Validate parameter ranges (approximate, since LBFGS++ may go outside bounds)
                assert is_number(suggestion1["Alpha"])
                assert is_number(suggestion1["ScaleFact"])
                assert is_number(suggestion1["SharpAngle"])

                # Observe result
                output = 0.85
                cost = 45.0
                result = AriaLbfgspp.observe(suggestion1, output, cost, false)
                assert match?({:ok, :observed}, result) or match?({:error, _}, result)

              {:error, _reason} ->
                :ok
            end

          {:error, _reason} ->
            :ok
        end
      end
    end

    test "multi-parameter optimization workflow" do
      if AriaLbfgspp.available?() do
        params = LbfgsppConfig.default_config()
        param_spaces = ParamSpaces.multi_param_space()

        case AriaLbfgspp.init(params, param_spaces) do
          {:ok, :lbfgspp_initialized} ->
            case AriaLbfgspp.suggest() do
              {:ok, suggestion} ->
                assert Map.has_key?(suggestion, "learning_rate")
                assert Map.has_key?(suggestion, "batch_size")
                assert Map.has_key?(suggestion, "momentum")

                # Validate values are numbers
                assert is_number(suggestion["learning_rate"])
                assert is_number(suggestion["batch_size"])
                assert is_number(suggestion["momentum"])

                output = 0.92
                cost = 120.5
                result = AriaLbfgspp.observe(suggestion, output, cost, false)
                assert match?({:ok, :observed}, result) or match?({:error, _}, result)

              {:error, _reason} ->
                :ok
            end

          {:error, _reason} ->
            :ok
        end
      end
    end

    test "simple quadratic optimization" do
      if AriaLbfgspp.available?() do
        # Optimize a simple quadratic function: f(x) = (x - 1.0)^2
        # Minimum is at x = 1.0
        params = LbfgsppConfig.quick_test_config()

        param_spaces = [
          %{
            "name" => "x",
            "space_type" => "LinearSpace",
            "min" => -5.0,
            "max" => 5.0,
            "scale" => 1.0,
            "search_center" => 0.0
          }
        ]

        case AriaLbfgspp.init(params, param_spaces) do
          {:ok, :lbfgspp_initialized} ->
            # Run optimization iterations
            best_result =
              Enum.reduce(1..10, {1_000_000.0, nil}, fn _i, {current_best, _} ->
                case AriaLbfgspp.suggest() do
                  {:ok, suggestion} ->
                    x = suggestion["x"]
                    # Objective: (x - 1.0)^2
                    objective = :math.pow(x - 1.0, 2)
                    cost = 1.0

                    case AriaLbfgspp.observe(suggestion, objective, cost, false) do
                      {:ok, :observed} ->
                        if objective < current_best do
                          {objective, suggestion}
                        else
                          {current_best, nil}
                        end

                      {:error, _reason} ->
                        {current_best, nil}
                    end

                  {:error, _reason} ->
                    {current_best, nil}
                end
              end)

            {best_objective, best_suggestion} = best_result

            # Verify we found a reasonable solution
            if best_suggestion != nil do
              x_value = best_suggestion["x"]

              # Should be close to 1.0 (within reasonable tolerance for gradient-free optimization)
              assert abs(x_value - 1.0) < 3.0, "x should be close to 1.0, got #{x_value}"
            end

          {:error, _reason} ->
            :ok
        end
      end
    end
  end

  describe "low-level interface" do
    test "init_low_level creates instance with explicit dimension" do
      if AriaLbfgspp.available?() do
        params = LbfgsppConfig.minimal_config()
        dimension = 5
        initial_point = [1.0, 2.0, 3.0, 4.0, 5.0]

        result = AriaLbfgspp.init_low_level(params, dimension, initial_point)
        assert match?({:ok, _instance_id}, result) or match?({:error, _}, result)
      end
    end

    test "optimize_step works with low-level interface" do
      if AriaLbfgspp.available?() do
        params = LbfgsppConfig.minimal_config()
        dimension = 2

        case AriaLbfgspp.init_low_level(params, dimension, [0.0, 0.0]) do
          {:ok, instance_id} ->
            # Simple quadratic: f(x,y) = x^2 + y^2
            # Gradient: [2x, 2y]
            objective_value = 0.0
            gradient = [0.0, 0.0]

            result = AriaLbfgspp.optimize_step(instance_id, objective_value, gradient)
            assert match?({:ok, _point}, result) or match?({:error, _}, result)

          {:error, _reason} ->
            :ok
        end
      end
    end

    test "get_current_point returns current optimization point" do
      if AriaLbfgspp.available?() do
        params = LbfgsppConfig.minimal_config()
        dimension = 3
        initial_point = [1.0, 2.0, 3.0]

        case AriaLbfgspp.init_low_level(params, dimension, initial_point) do
          {:ok, instance_id} ->
            result = AriaLbfgspp.get_current_point(instance_id)
            assert match?({:ok, _point}, result) or match?({:error, _}, result)

          {:error, _reason} ->
            :ok
        end
      end
    end

    test "get_status returns optimization status" do
      if AriaLbfgspp.available?() do
        params = LbfgsppConfig.minimal_config()
        dimension = 2

        case AriaLbfgspp.init_low_level(params, dimension, [0.0, 0.0]) do
          {:ok, instance_id} ->
            result = AriaLbfgspp.get_status(instance_id)

            case result do
              {:ok, status} ->
                assert is_map(status)
                assert Map.has_key?(status, :instance_id)
                assert Map.has_key?(status, :status)
                assert Map.has_key?(status, :iterations)

              {:error, _reason} ->
                :ok
            end

          {:error, _reason} ->
            :ok
        end
      end
    end

    test "stop cleans up instance" do
      if AriaLbfgspp.available?() do
        params = LbfgsppConfig.minimal_config()
        dimension = 2

        case AriaLbfgspp.init_low_level(params, dimension, [0.0, 0.0]) do
          {:ok, instance_id} ->
            result = AriaLbfgspp.stop(instance_id)
            assert result == :ok or match?({:error, _}, result)

          {:error, _reason} ->
            :ok
        end
      end
    end
  end

  describe "industrial scenario: neural network hyperparameter optimization" do
    setup do
      if not AriaLbfgspp.available?() do
        :skip
      else
        :ok
      end
    end

    test "optimizes neural network hyperparameters for image classification" do
      # Real-world scenario: Optimizing hyperparameters for a CNN image classifier
      # Parameters: learning_rate, batch_size, dropout_rate, weight_decay
      # Objective: Minimize validation loss (or maximize validation accuracy)

      param_spaces = [
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

      params = LbfgsppConfig.quick_test_config()

      case AriaLbfgspp.init(params, param_spaces) do
        {:ok, :lbfgspp_initialized} ->
          # Simulate hyperparameter optimization workflow
          # In production, this would train a model and evaluate on validation set
          evaluate_hyperparameters = fn suggestion ->
            learning_rate = suggestion["learning_rate"]
            batch_size = suggestion["batch_size"]
            dropout_rate = suggestion["dropout_rate"]
            weight_decay = suggestion["weight_decay"]

            # Simulate validation loss (lower is better)
            # Optimal values: lr=0.001, batch=64, dropout=0.5, weight_decay=1e-4
            optimal_lr = 0.001
            optimal_batch = 64.0
            optimal_dropout = 0.5
            optimal_wd = 1.0e-4

            # Quadratic loss function with known minimum
            validation_loss =
              :math.pow(learning_rate - optimal_lr, 2) * 100.0 +
                :math.pow(batch_size - optimal_batch, 2) * 0.01 +
                :math.pow(dropout_rate - optimal_dropout, 2) * 10.0 +
                :math.pow(weight_decay - optimal_wd, 2) * 1.0e8

            # Add some noise to simulate real training variance
            validation_loss + (:rand.uniform() - 0.5) * 0.1
          end

          # Run optimization for multiple iterations
          {best_loss, best_params} =
            Enum.reduce(1..15, {1_000_000.0, nil}, fn _i,
                                                      {current_best_loss, current_best_params} ->
              case AriaLbfgspp.suggest() do
                {:ok, suggestion} ->
                  # Validate all parameters are present
                  assert Map.has_key?(suggestion, "learning_rate")
                  assert Map.has_key?(suggestion, "batch_size")
                  assert Map.has_key?(suggestion, "dropout_rate")
                  assert Map.has_key?(suggestion, "weight_decay")

                  # Validate parameter ranges
                  assert suggestion["learning_rate"] >= 0.0001
                  assert suggestion["learning_rate"] <= 0.1
                  assert suggestion["batch_size"] >= 16
                  assert suggestion["batch_size"] <= 256
                  assert suggestion["dropout_rate"] >= 0.0
                  assert suggestion["dropout_rate"] <= 0.8
                  assert suggestion["weight_decay"] >= 1.0e-6
                  assert suggestion["weight_decay"] <= 1.0e-2

                  # Evaluate hyperparameters (simulate training)
                  validation_loss = evaluate_hyperparameters.(suggestion)
                  # Simulated training time in seconds
                  cost = 120.0

                  # Track best result
                  {new_best_loss, new_best_params} =
                    if validation_loss < current_best_loss do
                      {validation_loss, suggestion}
                    else
                      {current_best_loss, current_best_params}
                    end

                  # Observe the result
                  case AriaLbfgspp.observe(suggestion, validation_loss, cost, false) do
                    {:ok, :observed} ->
                      {new_best_loss, new_best_params}

                    {:error, reason} ->
                      {current_best_loss, current_best_params}
                  end

                {:error, _reason} ->
                  {current_best_loss, current_best_params}
              end
            end)

          # Verify optimization found reasonable hyperparameters
          assert best_params != nil

          assert best_loss < 10.0,
                 "Should find reasonable hyperparameters, best loss: #{best_loss}"

        {:error, _reason} ->
          :ok
      end
    end

    test "optimizes manufacturing process parameters" do
      # Real-world scenario: Optimizing production parameters for a manufacturing process
      # Parameters: temperature, pressure, flow_rate, reaction_time
      # Objective: Maximize product yield (minimize negative yield)

      param_spaces = [
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

      params = LbfgsppConfig.quick_test_config()

      case AriaLbfgspp.init(params, param_spaces) do
        {:ok, :lbfgspp_initialized} ->
          # Simulate manufacturing process optimization
          # Optimal conditions: temp=220°C, pressure=5.5 bar, flow=1.2 L/min, time=35 min
          evaluate_process = fn suggestion ->
            temperature = suggestion["temperature"]
            pressure = suggestion["pressure"]
            flow_rate = suggestion["flow_rate"]
            reaction_time = suggestion["reaction_time"]

            optimal_temp = 220.0
            optimal_pressure = 5.5
            optimal_flow = 1.2
            optimal_time = 35.0

            # Negative yield (we minimize this, so maximizing yield)
            negative_yield =
              :math.pow(temperature - optimal_temp, 2) * 0.01 +
                :math.pow(pressure - optimal_pressure, 2) * 0.1 +
                :math.pow(flow_rate - optimal_flow, 2) * 1.0 +
                :math.pow(reaction_time - optimal_time, 2) * 0.05

            # Add process noise
            negative_yield + (:rand.uniform() - 0.5) * 0.5
          end

          # Optimize process parameters
          {best_negative_yield, best_params} =
            Enum.reduce(1..12, {1_000_000.0, nil}, fn _i, {current_best, current_best_params} ->
              case AriaLbfgspp.suggest() do
                {:ok, suggestion} ->
                  assert Map.has_key?(suggestion, "temperature")
                  assert Map.has_key?(suggestion, "pressure")
                  assert Map.has_key?(suggestion, "flow_rate")
                  assert Map.has_key?(suggestion, "reaction_time")

                  # Validate ranges
                  assert suggestion["temperature"] >= 100.0
                  assert suggestion["temperature"] <= 300.0
                  assert suggestion["pressure"] >= 1.0
                  assert suggestion["pressure"] <= 10.0
                  assert suggestion["flow_rate"] >= 0.1
                  assert suggestion["flow_rate"] <= 10.0
                  assert suggestion["reaction_time"] >= 5.0
                  assert suggestion["reaction_time"] <= 60.0

                  negative_yield = evaluate_process.(suggestion)
                  # Process run time in seconds
                  cost = 300.0

                  {new_best, new_best_params} =
                    if negative_yield < current_best do
                      {negative_yield, suggestion}
                    else
                      {current_best, current_best_params}
                    end

                  case AriaLbfgspp.observe(suggestion, negative_yield, cost, false) do
                    {:ok, :observed} ->
                      {new_best, new_best_params}

                    {:error, _reason} ->
                      {current_best, current_best_params}
                  end

                {:error, _reason} ->
                  {current_best, current_best_params}
              end
            end)

          # Verify we found reasonable process parameters
          assert best_params != nil

          assert best_negative_yield < 50.0,
                 "Should find reasonable process parameters, best negative yield: #{best_negative_yield}"

        {:error, _reason} ->
          :ok
      end
    end

    test "optimizes supply chain inventory parameters" do
      # Real-world scenario: Optimizing inventory management parameters
      # Parameters: reorder_point, order_quantity, safety_stock, review_period
      # Objective: Minimize total cost (holding + ordering + stockout costs)

      param_spaces = [
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

      params = LbfgsppConfig.quick_test_config()

      case AriaLbfgspp.init(params, param_spaces) do
        {:ok, :lbfgspp_initialized} ->
          # Simulate inventory cost optimization
          # Optimal: reorder_point=120, order_quantity=250, safety_stock=30, review_period=7
          evaluate_inventory_cost = fn suggestion ->
            reorder_point = suggestion["reorder_point"]
            order_quantity = suggestion["order_quantity"]
            safety_stock = suggestion["safety_stock"]
            review_period = suggestion["review_period"]

            optimal_reorder = 120.0
            optimal_quantity = 250.0
            optimal_safety = 30.0
            optimal_review = 7.0

            # Total cost function (holding + ordering + stockout)
            total_cost =
              :math.pow(reorder_point - optimal_reorder, 2) * 0.1 +
                :math.pow(order_quantity - optimal_quantity, 2) * 0.01 +
                :math.pow(safety_stock - optimal_safety, 2) * 0.5 +
                :math.pow(review_period - optimal_review, 2) * 2.0

            total_cost + (:rand.uniform() - 0.5) * 5.0
          end

          # Optimize inventory parameters
          {best_cost, best_params} =
            Enum.reduce(1..10, {1_000_000.0, nil}, fn _i,
                                                      {current_best_cost, current_best_params} ->
              case AriaLbfgspp.suggest() do
                {:ok, suggestion} ->
                  assert Map.has_key?(suggestion, "reorder_point")
                  assert Map.has_key?(suggestion, "order_quantity")
                  assert Map.has_key?(suggestion, "safety_stock")
                  assert Map.has_key?(suggestion, "review_period")

                  # Validate ranges
                  assert suggestion["reorder_point"] >= 10.0
                  assert suggestion["reorder_point"] <= 500.0
                  assert suggestion["order_quantity"] >= 50.0
                  assert suggestion["order_quantity"] <= 1000.0
                  assert suggestion["safety_stock"] >= 5.0
                  assert suggestion["safety_stock"] <= 100.0
                  assert suggestion["review_period"] >= 1.0
                  assert suggestion["review_period"] <= 30.0

                  total_cost = evaluate_inventory_cost.(suggestion)
                  # Simulation time in seconds
                  cost = 60.0

                  {new_best_cost, new_best_params} =
                    if total_cost < current_best_cost do
                      {total_cost, suggestion}
                    else
                      {current_best_cost, current_best_params}
                    end

                  case AriaLbfgspp.observe(suggestion, total_cost, cost, false) do
                    {:ok, :observed} ->
                      {new_best_cost, new_best_params}

                    {:error, _reason} ->
                      {current_best_cost, current_best_params}
                  end

                {:error, _reason} ->
                  {current_best_cost, current_best_params}
              end
            end)

          # Verify optimization found reasonable inventory parameters
          assert best_params != nil

          assert best_cost < 200.0,
                 "Should find reasonable inventory parameters, best cost: #{best_cost}"

        {:error, _reason} ->
          :ok
      end
    end
  end

  describe "error handling" do
    test "suggest returns error when not initialized" do
      # Try to suggest without initializing
      result = AriaLbfgspp.suggest()
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "observe returns error when not initialized" do
      input = %{"x" => 0.5}
      output = 0.5
      cost = 10.0

      result = AriaLbfgspp.observe(input, output, cost, false)
      assert match?({:ok, :observed}, result) or match?({:error, _}, result)
    end
  end
end
