LatestGameState = LatestGameState or nil
InAction = InAction or false
currentPlayer = nil
Logs = Logs or {}

colors = {
  red = "\27[31m",
  green = "\27[32m",
  blue = "\27[34m",
  reset = "\27[0m",
  gray = "\27[90m"
}

function addLog(msg, text)
  Logs[msg] = Logs[msg] or {}
  table.insert(Logs[msg], text)
end

function inRange(Player)
    return math.abs(currentPlayer.x - Player.x) <= 1 and math.abs(currentPlayer.y - Player.y) <= 1
end

function decideNextAction()
  local targetInRange = false
  local myHealth = currentPlayer.health
  local lastPlayer = nil
  print("My current health: " .. myHealth)
  for target, state in pairs(LatestGameState.Players) do
    if target ~= ao.id and inRange(state) then
        if myHealth >= 30 then
          targetInRange = true
          break
        elseif myHealth <= 30 then
          print(colors.red .. "No player in range or insufficient energy. Moving" .. colors.reset)
          local directionMap = {"Up", "Down", "Left", "Right", "UpRight", "UpLeft", "DownRight", "DownLeft"}
          local randomIndex = math.random(#directionMap)
          print("Not enough health, evading for now.")
          for i = 1, 3, 1 do
            ao.send({Target = Game, Action = "PlayerMove", Player = ao.id, Direction = directionMap[randomIndex]})
          end
        end
    end
    lastPlayer = state
  end
  if currentPlayer.energy > 20 and targetInRange then
    print(colors.red .. "Player in range. Initiating attack." .. colors.reset)
    ao.send({Target = Game, Action = "PlayerAttack", Player = ao.id, AttackEnergy = tostring(currentPlayer.energy)})
  else
    if currentPlayer.x - lastPlayer.x > 0 then
      ao.send({Target = Game, Action = "PlayerMove", Player = ao.id, Direction = "Right"})
    end
    if currentPlayer.y - lastPlayer.y > 0 then 
      ao.send({Target = Game, Action = "PlayerMove", Player = ao.id, Direction = "Down"})
    end
  end
  InAction = false
end

Handlers.add(
  "PrintAnnouncements",
  Handlers.utils.hasMatchingTag("Action", "Announcement"),
  function (msg)
    if msg.Event == "Started-Waiting-Period" then
      ao.send({Target = ao.id, Action = "AutoPay"})
    elseif (msg.Event == "Tick" or msg.Event == "Started-Game") and not InAction then
      InAction = true
      ao.send({Target = Game, Action = "GetGameState"})
    elseif InAction then
      print("Previous action still in progress. Skipping.")
    end
    print(colors.green .. msg.Event .. ": " .. msg.Data .. colors.reset)
  end
)

Handlers.add(
  "GetGameStateOnTick",
  Handlers.utils.hasMatchingTag("Action", "Tick"),
  function ()
    if not InAction then
      InAction = true
      print(colors.gray .. "Getting game state..." .. colors.reset)
      ao.send({Target = Game, Action = "GetGameState"})
    else
      print("Previous action still in progress. Skipping.")
    end
  end
)

Handlers.add(
  "AutoPay",
  Handlers.utils.hasMatchingTag("Action", "AutoPay"),
  function (msg)
    print("Auto-paying confirmation fees.")
    ao.send({ Target = Game, Action = "Transfer", Recipient = Game, Quantity = "1000"})
  end
)

Handlers.add(
  "UpdateGameState",
  Handlers.utils.hasMatchingTag("Action", "GameState"),
  function (msg)
    local json = require("json")
    LatestGameState = json.decode(msg.Data)
    ao.send({Target = ao.id, Action = "UpdatedGameState"})
    print("Game state updated. Print \'LatestGameState\' for detailed view.")
  end
)

Handlers.add(
  "decideNextAction",
  Handlers.utils.hasMatchingTag("Action", "UpdatedGameState"),
  function ()
    if LatestGameState.GameMode ~= "Playing" then
      InAction = false
      return
    end
    print("Deciding next action.")
    decideNextAction()
    ao.send({Target = ao.id, Action = "Tick"})
  end
)

Handlers.add(
  "ReturnAttack",
  Handlers.utils.hasMatchingTag("Action", "Hit"),
  function (msg)
    if not InAction then
      InAction = true
      local playerEnergy = currentPlayer.energy or 0
      if playerEnergy == 0 then
        print(colors.red .. "Player has insufficient energy." .. colors.reset)
        ao.send({Target = Game, Action = "Attack-Failed", Reason = "Player has no energy."})
      else
        print(colors.red .. "Returning attack." .. colors.reset)
        ao.send({Target = Game, Action = "PlayerAttack", Player = ao.id, AttackEnergy = tostring(playerEnergy)})
      end
      InAction = false
      ao.send({Target = ao.id, Action = "Tick"})
    else
      local directionMap = {"Up", "Down", "Left", "Right", "UpRight", "UpLeft", "DownRight", "DownLeft"}
      local randomIndex = math.random(#directionMap)
      ao.send({Target = Game, Action = "PlayerMove", Player = ao.id, Direction = directionMap[randomIndex]})
      print("Previous action still in progress. Skipping.")
    end
  end
)