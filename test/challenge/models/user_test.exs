defmodule Challenge.Models.UserTest do
  use ExUnit.Case

  doctest Challenge.Models.User

  alias Challenge.Models.User

  test "returns a new model if user id is valid" do
    user_id = "parth"
    assert %User{id: ^user_id} = User.new(%{id: user_id})
  end

  test "returns error if user id is invalid" do
    user_id = ""
    assert {:error, :invalid_name} = User.new(%{id: user_id})
  end

  test "returns error if user id length is less than 3" do
    user_id = "aa"
    assert {:error, :invalid_name} = User.new(%{id: user_id})
  end
end
