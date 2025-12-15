defmodule WandererKills.Integration.ZkbValueFieldsTest do
  @moduledoc """
  Integration tests for droppedValue and destroyedValue fields in zkb payload.

  These tests verify that ISK value fields flow correctly from the zKillboard
  data source through the processing pipeline to the final WebSocket payload.

  Feature: Add droppedValue and destroyedValue to zkb payload
  Use case: ISK-value-based color coding for Discord notifications
  """

  use ExUnit.Case, async: true

  alias WandererKills.Domain.{Killmail, ZkbMetadata, Victim, Attacker}

  describe "ZkbMetadata field parsing" do
    test "parses droppedValue and destroyedValue from camelCase input" do
      zkb_data = %{
        "hash" => "test_hash_123",
        "totalValue" => 1_000_000.0,
        "droppedValue" => 350_000.0,
        "destroyedValue" => 650_000.0,
        "fittedValue" => 700_000.0,
        "points" => 10,
        "npc" => false,
        "solo" => false,
        "awox" => false,
        "locationID" => 31_000_001
      }

      {:ok, metadata} = ZkbMetadata.new(zkb_data)

      assert metadata.dropped_value == 350_000.0
      assert metadata.destroyed_value == 650_000.0
      assert metadata.total_value == 1_000_000.0
      assert metadata.fitted_value == 700_000.0
    end

    test "parses droppedValue and destroyedValue from snake_case input" do
      zkb_data = %{
        "hash" => "test_hash_456",
        "total_value" => 2_000_000.0,
        "dropped_value" => 800_000.0,
        "destroyed_value" => 1_200_000.0,
        "fitted_value" => 1_500_000.0,
        "points" => 5,
        "npc" => true,
        "solo" => true,
        "awox" => false,
        "location_id" => 31_000_002
      }

      {:ok, metadata} = ZkbMetadata.new(zkb_data)

      assert metadata.dropped_value == 800_000.0
      assert metadata.destroyed_value == 1_200_000.0
      assert metadata.total_value == 2_000_000.0
    end

    test "handles missing droppedValue and destroyedValue gracefully" do
      zkb_data = %{
        "hash" => "test_hash_789",
        "totalValue" => 500_000.0,
        "points" => 1,
        "npc" => false,
        "solo" => false,
        "awox" => false
      }

      {:ok, metadata} = ZkbMetadata.new(zkb_data)

      assert metadata.dropped_value == nil
      assert metadata.destroyed_value == nil
      assert metadata.total_value == 500_000.0
    end

    test "handles zero values for droppedValue and destroyedValue" do
      zkb_data = %{
        "hash" => "test_hash_zero",
        "totalValue" => 100_000.0,
        "droppedValue" => 0.0,
        "destroyedValue" => 100_000.0,
        "points" => 1,
        "npc" => false,
        "solo" => false,
        "awox" => false
      }

      {:ok, metadata} = ZkbMetadata.new(zkb_data)

      # Zero should be preserved, not treated as nil
      assert metadata.dropped_value == 0.0
      assert metadata.destroyed_value == 100_000.0
    end
  end

  describe "ZkbMetadata JSON serialization" do
    test "serializes droppedValue and destroyedValue to camelCase" do
      zkb = %ZkbMetadata{
        hash: "test_hash",
        total_value: 1_000_000.0,
        dropped_value: 350_000.0,
        destroyed_value: 650_000.0,
        fitted_value: 700_000.0,
        points: 10,
        npc: false,
        solo: false,
        awox: false,
        location_id: 31_000_001,
        labels: nil
      }

      json = Jason.encode!(zkb)
      decoded = Jason.decode!(json)

      assert decoded["droppedValue"] == 350_000.0
      assert decoded["destroyedValue"] == 650_000.0
      assert decoded["totalValue"] == 1_000_000.0
      assert decoded["fittedValue"] == 700_000.0
    end

    test "excludes nil optional values from JSON output" do
      zkb = %ZkbMetadata{
        hash: "test_hash",
        total_value: 1_000_000.0,
        dropped_value: nil,
        destroyed_value: nil,
        fitted_value: nil,
        points: 10,
        npc: false,
        solo: false,
        awox: false,
        location_id: nil,
        labels: nil
      }

      json = Jason.encode!(zkb)
      decoded = Jason.decode!(json)

      # Optional fields (using maybe_add_field) are excluded when nil
      refute Map.has_key?(decoded, "droppedValue")
      refute Map.has_key?(decoded, "destroyedValue")
      refute Map.has_key?(decoded, "fittedValue")
      refute Map.has_key?(decoded, "labels")

      # Required/base fields are always included (even if nil)
      assert decoded["totalValue"] == 1_000_000.0
      assert Map.has_key?(decoded, "locationID")
      assert Map.has_key?(decoded, "hash")
    end

    test "includes zero values in JSON output" do
      zkb = %ZkbMetadata{
        hash: "test_hash",
        total_value: 100_000.0,
        dropped_value: 0.0,
        destroyed_value: 100_000.0,
        fitted_value: 0.0,
        points: 1,
        npc: false,
        solo: false,
        awox: false,
        location_id: 31_000_001,
        labels: nil
      }

      json = Jason.encode!(zkb)
      decoded = Jason.decode!(json)

      # Zero values should be included
      assert decoded["droppedValue"] == 0.0
      assert decoded["destroyedValue"] == 100_000.0
      assert decoded["fittedValue"] == 0.0
    end
  end

  describe "Full Killmail serialization with zkb fields" do
    test "killmail struct serializes zkb with droppedValue and destroyedValue" do
      victim = %Victim{
        character_id: 95_465_499,
        ship_type_id: 587,
        damage_taken: 1337
      }

      attacker = %Attacker{
        character_id: 95_465_500,
        damage_done: 1337,
        final_blow: true
      }

      zkb = %ZkbMetadata{
        hash: "abc123def456",
        total_value: 5_000_000_000.0,
        dropped_value: 2_000_000_000.0,
        destroyed_value: 3_000_000_000.0,
        fitted_value: 4_500_000_000.0,
        points: 100,
        npc: false,
        solo: true,
        awox: false,
        location_id: 40_000_001,
        labels: ["expensive"]
      }

      killmail = %Killmail{
        killmail_id: 123_456_789,
        kill_time: ~U[2024-01-15 10:30:45Z],
        system_id: 30_000_142,
        victim: victim,
        attackers: [attacker],
        zkb: zkb,
        attacker_count: 1
      }

      json = Jason.encode!(killmail)
      decoded = Jason.decode!(json)

      # Verify zkb fields in final payload
      assert decoded["zkb"]["totalValue"] == 5_000_000_000.0
      assert decoded["zkb"]["droppedValue"] == 2_000_000_000.0
      assert decoded["zkb"]["destroyedValue"] == 3_000_000_000.0
      assert decoded["zkb"]["fittedValue"] == 4_500_000_000.0
      assert decoded["zkb"]["points"] == 100
      assert decoded["zkb"]["solo"] == true
      assert decoded["zkb"]["labels"] == ["expensive"]
    end
  end

  describe "ISK value color coding use case" do
    @doc """
    Tests the use case described in the feature request:
    Color coding based on ISK value for Discord notifications.
    """

    test "can determine color based on droppedValue thresholds" do
      # ISK Value thresholds from feature request:
      # >= 5B: Red (very high)
      # >= 1B: Orange (high)
      # >= 100M: Yellow (medium)
      # >= 10M: Green (low)
      # < 10M: Gray (minimal)

      test_cases = [
        {5_500_000_000.0, :red},
        {1_500_000_000.0, :orange},
        {500_000_000.0, :yellow},
        {50_000_000.0, :green},
        {5_000_000.0, :gray}
      ]

      for {dropped_value, expected_color} <- test_cases do
        zkb_data = %{
          "hash" => "test_hash",
          "totalValue" => dropped_value * 2,
          "droppedValue" => dropped_value,
          "destroyedValue" => dropped_value,
          "points" => 10,
          "npc" => false,
          "solo" => false,
          "awox" => false
        }

        {:ok, metadata} = ZkbMetadata.new(zkb_data)
        actual_color = get_color_for_value(metadata.dropped_value)

        assert actual_color == expected_color,
               "Expected #{expected_color} for #{dropped_value} ISK, got #{actual_color}"
      end
    end

    test "fallback behavior when droppedValue is nil uses totalValue" do
      zkb_data = %{
        "hash" => "test_hash",
        "totalValue" => 2_000_000_000.0,
        "points" => 10,
        "npc" => false,
        "solo" => false,
        "awox" => false
      }

      {:ok, metadata} = ZkbMetadata.new(zkb_data)

      # Fallback logic as described in feature request
      value = metadata.dropped_value || metadata.total_value || 0
      assert value == 2_000_000_000.0
      assert get_color_for_value(value) == :orange
    end
  end

  # Helper function to determine color based on ISK value
  defp get_color_for_value(value) when is_number(value) do
    cond do
      value >= 5_000_000_000 -> :red
      value >= 1_000_000_000 -> :orange
      value >= 100_000_000 -> :yellow
      value >= 10_000_000 -> :green
      true -> :gray
    end
  end

  defp get_color_for_value(_), do: :gray
end
