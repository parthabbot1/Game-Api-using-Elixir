defmodule ChallengeTest do
  use ExUnit.Case
  doctest Challenge

  @registry Challenge.Registry

  @bet %{
    user: "john12345",
    transaction_uuid: "16d2dcfe-b89e-11e7-854a-58404eea6d16",
    supplier_transaction_id: "41ecc3ad-b181-4235-bf9d-acf0a7ad9730",
    token: "55b7518e-b89e-11e7-81be-58404eea6d16",
    supplier_user: "cg_45141",
    round_closed: true,
    round: "rNEMwgzJAOZ6eR3V",
    reward_uuid: "a28f93f2-98c5-41f7-8fbb-967985acf8fe",
    request_uuid: "583c985f-fee6-4c0e-bbf5-308aad6265af",
    is_free: false,
    is_aggregated: false,
    game_code: "clt_dragonrising",
    currency: "USD",
    bet: "zero",
    amount: 1000,
    meta: %{
      selection: "home_team",
      odds: 2.5
    }
  }

  setup_all do
    pid = Challenge.start()
    %{supervisor_pid: pid}
  end

  describe "start/0 - " do
    test "starts the supervision tree successfully.", %{supervisor_pid: spid} do
      assert is_pid(spid) == true
    end

    test "starts the another supervision tree successfully.", %{supervisor_pid: spid} do
      assert is_pid(spid) == true

      npid = Challenge.start()
      assert npid != spid
    end
  end

  describe "create_users/2 - " do
    test "create a new user when a valid user id is provided", %{supervisor_pid: spid} do
      user_id = "test_user"
      assert :ok = Challenge.create_users(spid, [user_id])
      [{pid, nil}] = Registry.lookup(@registry, get_user(spid, user_id))
      assert is_pid(pid) == true
    end

    test "no user is created when an invalid user id is provided", %{supervisor_pid: spid} do
      user_ids = [:att, ""]
      assert :ok = Challenge.create_users(spid, user_ids)
      assert [] = Registry.lookup(@registry, get_user(spid, ""))
      assert [] = Registry.lookup(@registry, get_user(spid, :att))
    end

    test "user is not re-initialised if we start child again", %{supervisor_pid: spid} do
      user_id = "test_user1"
      assert :ok = Challenge.create_users(spid, [user_id])
      [{pid, nil}] = Registry.lookup(@registry, get_user(spid, user_id))
      assert is_pid(pid) == true

      assert :ok = Challenge.create_users(spid, [user_id])
      [{^pid, nil}] = Registry.lookup(@registry, get_user(spid, user_id))
    end
  end

  describe "bet/2 - " do
    test "places bet successfully for a user if the bet params are valid.", %{
      supervisor_pid: spid
    } do
      user = "parth"
      assert :ok = Challenge.create_users(spid, [user])
      [{pid, nil}] = Registry.lookup(@registry, get_user(spid, user))
      assert is_pid(pid) == true

      request_uuid = "583c985f-fee6-4c0e-bbf5-308aad6265af"

      bet = %{
        @bet
        | user: user,
          request_uuid: request_uuid,
          transaction_uuid: "16d2dcfe-b89e-11e7-854a-58404eea4316"
      }

      assert %{
               user: ^user,
               status: "RS_OK",
               request_uuid: ^request_uuid,
               currency: "USD",
               balance: 99_000
             } = Challenge.bet(spid, bet)
    end

    test "does-not places bet if a different root server is provided.", %{
      supervisor_pid: spid
    } do
      user = "parthdiff"
      assert :ok = Challenge.create_users(spid, [user])
      [{pid, nil}] = Registry.lookup(@registry, get_user(spid, user))
      assert is_pid(pid) == true

      npid = Challenge.start()

      request_uuid = "583c985f-fee6-4c0e-bbf5-308aad6265af"

      bet = %{
        @bet
        | user: user,
          request_uuid: request_uuid,
          transaction_uuid: "16d2dcfe-b89e-11e7-854a-58404essdad16"
      }

      assert %{
               user: ^user,
               status: "RS_OK",
               request_uuid: ^request_uuid,
               currency: "USD",
               balance: 99_000
             } = Challenge.bet(spid, bet)

      bet = %{
        @bet
        | user: user,
          transaction_uuid: "583c985f-fee6-4c0e-bbf5-308aad6265af",
          request_uuid: request_uuid
      }

      assert %{
               status: "RS_ERROR_UNKNOWN"
             } = Challenge.bet(npid, bet)
    end

    test "returns error id user doesnot exists.", %{supervisor_pid: spid} do
      bet = %{@bet | user: "some user"}

      assert %{status: "RS_ERROR_UNKNOWN"} = Challenge.bet(spid, bet)
    end

    test "idempotency - does not places bet if transaction uuid is duplicate", %{
      supervisor_pid: spid
    } do
      user = "parth1"
      assert :ok = Challenge.create_users(spid, [user])
      [{pid, nil}] = Registry.lookup(@registry, get_user(spid, user))
      assert is_pid(pid) == true

      bet = %{
        @bet
        | user: user,
          amount: 3000,
          transaction_uuid: "16d2dcfe-b89e-11e7-854a-58404eeassd16"
      }

      assert %{
               user: ^user,
               status: "RS_OK",
               request_uuid: _,
               currency: "USD",
               balance: 97_000
             } = Challenge.bet(spid, bet)

      assert %{
               user: ^user,
               status: "RS_OK",
               request_uuid: _,
               currency: "USD",
               balance: 97_000
             } = Challenge.bet(spid, bet)
    end

    test "does not places bet if bet amount is negative", %{supervisor_pid: spid} do
      user = "parth2"
      assert :ok = Challenge.create_users(spid, [user])
      [{pid, nil}] = Registry.lookup(@registry, get_user(spid, user))
      assert is_pid(pid) == true

      bet = %{@bet | user: user, amount: -200}

      assert %{
               status: "RS_ERROR_WRONG_TYPES"
             } = Challenge.bet(spid, bet)
    end

    test "does not places bet if bet amount is invalid", %{supervisor_pid: spid} do
      user = "parth3"
      assert :ok = Challenge.create_users(spid, [user])
      [{pid, nil}] = Registry.lookup(@registry, get_user(spid, user))
      assert is_pid(pid) == true

      bet = %{
        @bet
        | user: user,
          amount: 200_000,
          transaction_uuid: "16d2dsfe-b89e-11e7-854a-58404eea6d16"
      }

      assert %{
               status: "RS_ERROR_NOT_ENOUGH_MONEY"
             } = Challenge.bet(spid, bet)
    end

    test "does not places bet if currency code is not USD", %{supervisor_pid: spid} do
      user = "parth4"
      assert :ok = Challenge.create_users(spid, [user])
      [{pid, nil}] = Registry.lookup(@registry, get_user(spid, user))
      assert is_pid(pid) == true

      bet = %{
        @bet
        | user: user,
          amount: 122,
          currency: "INR",
          transaction_uuid: "16ddddcfe-b89e-11e7-854a-58404eea6d16"
      }

      assert %{
               status: "RS_ERROR_WRONG_CURRENCY"
             } = Challenge.bet(spid, bet)
    end

    test "does not places bet if game code is invalid", %{supervisor_pid: spid} do
      user = "parth5"
      assert :ok = Challenge.create_users(spid, [user])
      [{pid, nil}] = Registry.lookup(@registry, get_user(spid, user))
      assert is_pid(pid) == true

      bet = %{@bet | user: user, amount: 122, game_code: ""}

      assert %{
               status: "RS_ERROR_WRONG_TYPES"
             } = Challenge.bet(spid, bet)
    end

    test "returns error when payload is incorrect.", %{supervisor_pid: spid} do
      user = "parth5"
      assert :ok = Challenge.create_users(spid, [user])
      [{pid, nil}] = Registry.lookup(@registry, get_user(spid, user))
      assert is_pid(pid) == true

      bet = %{
        user: user,
        transaction_uuid: "16d2dcfe-b89e-11e7-854a-58404eea6d16",
        supplier_transaction_id: "41ecc3ad-b181-4235-bf9d-acf0a7ad9730",
        token: "55b7518e-b89e-11e7-81be-58404eea6d16",
        supplier_user: "cg_45141",
        bet: "zero",
        amount: 1000,
        meta: %{
          selection: "home_team",
          odds: 2.5
        }
      }

      assert %{
               status: "RS_ERROR_WRONG_SYNTAX"
             } = Challenge.bet(spid, bet)
    end
  end

  describe "win/2 - " do
    @win %{
      user: "john12345",
      transaction_uuid: "16d2dcfe-b89e-11e7-854a-58404eea6d16",
      supplier_transaction_id: "41ecc3ad-b181-4235-bf9d-acf0a7ad9730",
      token: "55b7518e-b89e-11e7-81be-58404eea6d16",
      supplier_user: "cg_45141",
      round_closed: true,
      round: "rNEMwgzJAOZ6eR3V",
      reward_uuid: "a28f93f2-98c5-41f7-8fbb-967985acf8fe",
      request_uuid: "583c985f-fee6-4c0e-bbf5-308aad6265af",
      reference_transaction_uuid: "16d2dcfe-b89e-11e7-854a-58404eea6d16",
      is_free: false,
      is_aggregated: false,
      game_code: "clt_dragonrising",
      currency: "USD",
      bet: "zero",
      amount: 1000,
      meta: %{
        selection: "home_team",
        odds: 2.5
      }
    }

    test "processes win request successfully when request params are valid.", %{
      supervisor_pid: spid
    } do
      user = "parthwin1"
      assert :ok = Challenge.create_users(spid, [user])
      [{pid, nil}] = Registry.lookup(@registry, get_user(spid, user))
      assert is_pid(pid) == true

      request_uuid = "583c985f-fee6-4c0e-bbf5-308aad6265af"

      bet = %{@bet | user: user, request_uuid: request_uuid}

      assert %{
               user: ^user,
               status: "RS_OK",
               request_uuid: ^request_uuid,
               currency: "USD",
               balance: 99_000
             } = Challenge.bet(spid, bet)

      win = %{
        @win
        | user: user,
          request_uuid: request_uuid,
          amount: 1500,
          transaction_uuid: "16d2dcfe-b89e-11e7-854a-5s40aaea6d16"
      }

      assert %{
               user: ^user,
               status: "RS_OK",
               request_uuid: ^request_uuid,
               currency: "USD",
               balance: 100_500
             } = Challenge.win(spid, win)

      bet = %{
        @bet
        | user: user,
          request_uuid: request_uuid,
          transaction_uuid: "583c985f-fee6-4c0e-bbf5-308aad6265af"
      }

      assert %{
               user: ^user,
               status: "RS_OK",
               request_uuid: ^request_uuid,
               currency: "USD",
               balance: 99_500
             } = Challenge.bet(spid, bet)
    end

    test "returns error id user doesnot exists.", %{supervisor_pid: spid} do
      user = "parthwin2"
      assert :ok = Challenge.create_users(spid, [user])
      [{pid, nil}] = Registry.lookup(@registry, get_user(spid, user))
      assert is_pid(pid) == true

      request_uuid = "583c985f-fee6-4c0e-bbf5-308aad6265af"

      bet = %{
        @bet
        | user: user,
          request_uuid: request_uuid,
          transaction_uuid: "16d2dcfe-b89e-11e7-854a-58404eea6add6"
      }

      assert %{
               user: ^user,
               status: "RS_OK",
               request_uuid: ^request_uuid,
               currency: "USD",
               balance: 99_000
             } = Challenge.bet(spid, bet)

      win = %{@win | user: "some user", request_uuid: request_uuid, amount: 1500}

      assert %{status: "RS_ERROR_UNKNOWN"} = Challenge.win(spid, win)
    end

    test "returns error if reference_transaction_uuid is invalid.", %{supervisor_pid: spid} do
      user = "parthwin4"
      assert :ok = Challenge.create_users(spid, [user])
      [{pid, nil}] = Registry.lookup(@registry, get_user(spid, user))
      assert is_pid(pid) == true

      request_uuid = "583c985f-fee6-4c0e-bbf5-308aad6265af"

      bet = %{
        @bet
        | user: user,
          request_uuid: request_uuid,
          transaction_uuid: "16d2dcfe-b89e-11e7-854a-58404ssa6d16"
      }

      assert %{
               user: ^user,
               status: "RS_OK",
               request_uuid: ^request_uuid,
               currency: "USD",
               balance: 99_000
             } = Challenge.bet(spid, bet)

      win = %{
        @win
        | user: user,
          request_uuid: request_uuid,
          amount: 1500,
          reference_transaction_uuid: "some id"
      }
    end

    test "does not process win if win amount is negative", %{supervisor_pid: spid} do
      user = "parthwin5"
      assert :ok = Challenge.create_users(spid, [user])
      [{pid, nil}] = Registry.lookup(@registry, get_user(spid, user))
      assert is_pid(pid) == true

      request_uuid = "583c985f-fee6-4c0e-bbf5-308aad6265af"

      bet = %{
        @bet
        | user: user,
          request_uuid: request_uuid,
          transaction_uuid: "16d2dcfe-b89e-1sse7-854a-58404eea6d16"
      }

      assert %{
               user: ^user,
               status: "RS_OK",
               request_uuid: ^request_uuid,
               currency: "USD",
               balance: 99_000
             } = Challenge.bet(spid, bet)

      win = %{@win | user: user, request_uuid: request_uuid, amount: -1500}

      assert %{
               status: "RS_ERROR_WRONG_TYPES"
             } = Challenge.win(spid, win)
    end

    test "returns error when payload is incorrect.", %{supervisor_pid: spid} do
      user = "parthwin7"
      assert :ok = Challenge.create_users(spid, [user])
      [{pid, nil}] = Registry.lookup(@registry, get_user(spid, user))
      assert is_pid(pid) == true

      request_uuid = "583c985f-fee6-4c0e-bbf5-308aad6265af"

      bet = %{
        @bet
        | user: user,
          request_uuid: request_uuid,
          transaction_uuid: "16ss2dcfe-b89e-11e7-854a-58404eea6d16"
      }

      assert %{
               user: ^user,
               status: "RS_OK",
               request_uuid: ^request_uuid,
               currency: "USD",
               balance: 99_000
             } = Challenge.bet(spid, bet)

      win = %{user: user}

      assert %{
               status: "RS_ERROR_WRONG_SYNTAX"
             } = Challenge.win(spid, win)
    end

    test "does not process win if places at a different root server.", %{
      supervisor_pid: spid
    } do
      user = "parthwin8"
      assert :ok = Challenge.create_users(spid, [user])
      [{pid, nil}] = Registry.lookup(@registry, get_user(spid, user))
      assert is_pid(pid) == true

      request_uuid = "583c985f-fee6-4c0e-bbf5-308aad6265af"

      bet = %{
        @bet
        | user: user,
          request_uuid: request_uuid,
          transaction_uuid: "16d2dcfe-b89e-11e7-854a-58a04eea6d16"
      }

      assert %{
               user: ^user,
               status: "RS_OK",
               request_uuid: ^request_uuid,
               currency: "USD",
               balance: 99_000
             } = Challenge.bet(spid, bet)

      npid = Challenge.start()
      win = %{@win | user: user, request_uuid: request_uuid, amount: 1500}

      assert %{
               status: "RS_ERROR_UNKNOWN"
             } = Challenge.win(npid, win)
    end
  end

  defp get_user(pid, user), do: "#{user}_#{inspect(pid)}"
end
