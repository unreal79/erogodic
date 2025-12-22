local Ero = require 'libs.erogodic'
local Talkies = require 'libs.talkies'

local Example2 = {
  imgAvatar = nil,
  sndTalk = nil,
  sndType = nil,
  displayMode = nil,
}

local script = Ero(function()
  name("Tutorial")
  config({
    image = Example2.imgAvatar,
    imageOnLeft = false,
    titleColor = {1, 1, 1, 0.8},
    titleOnLeft = false,
    textSpeed = "fast",
    typedNotTalked = false,
    talkSound = Example2.sndTalk,
    height = 230,
    onstart = function(dialog)
      print("Are we showing? -", dialog:isShown())
    end,
    onmessage = function(dialog, left)
      print(left .. " messages left in the dialog. Is showing? -", dialog:isShown())
    end,
    oncomplete = function(dialog)
      print("Are we still showing? -", dialog:isShown())
    end
  })
  msg({
    "Talkies is a simple to use message-box library.",
    "Talkies includes:\nMultiple choices, UTF8 text, Pauses, -- Onstart/OnMessage/Oncomplete " ..
    "functions, Complete customization, Variable typing speeds amongst other things."
  })

  name("Selecting options")
  -- Talkies.height = 150
  config({
    textSpeed = "slow",
    typedNotTalked = true,
    talkSound = Example2.sndType,
    height = 150,
  })
  msg("Typing sound is aligned with the text speed...")

  local red = option("Red")
  local blue = option("Blue")
  local green = option("Green")
  config({
    textSpeed = "slow",
  })
  menu("Here's some options:")
  if selection(red) then
    selectedColor("Red")
  elseif selection(blue) then
    selectedColor("Blue")
  elseif selection(green) then
    selectedColor("Green")
  end

  local red = option("Red")
  local blue = option("Blue")
  local green = option("Green")
  config({
    textSpeed = "fast",
    inlineOptions = false,
    messageColor = {0.3, 1, 0.5, 0.9},
    messageBackgroundColor = {0.5, 0.5, 0.5, 0.9},
    selectedTextColor = {0, 0, 0, 1},
    selectedBackgroundColor = {0, 0, 1, 0.8},
  })
  menu("Here's some options again:")
  if selection(red) then
    selectedColor("Red")
  elseif selection(blue) then
    selectedColor("Blue")
  elseif selection(green) then
    selectedColor("Green")
  end

  config({
    image = Example2.imgAvatar,
    titleColor = {1, 1, 1, 0.8},
    textSpeed = "fast",
    typedNotTalked = false,
    talkSound = Example2.sndTalk,
  })
  name("Tutorial")
  msg("Each message is added to a \"message queue\", " ..
      "i.e. they're presented in the order that they're called. This is part " ..
      "of the design of Möan.lua")

  name("UTF8 example")
  msg("アイ・ドーント・ノー・ジャパニーズ・ホープフリー・ジス・トランズレーター・ダズント・" ..
      "メス・ジス・アップ・トゥー・マッチ")
  name("Tutorial")
  config({
    textSpeed = "instant",
  })
  msg({
    "That's all for this demo of Talkies.lua!",
    "You can find the source code at " ..
    "https://github.com/erogodic/Talkies",
    "Goodbye. See ya around!"
  })
end)
:defineAttributes({
  'name',
  'config',
})
:addMacro('selectedColor', function(item)
  if item == "Red" then
    love.graphics.setBackgroundColor(0.5, 0, 0)
  elseif item == "Blue" then
    love.graphics.setBackgroundColor(0, 0, 0.5)
  elseif item == "Green" then
    love.graphics.setBackgroundColor(0, 0.5, 0)
  end
  local lastName = get('name')
  name("")
  msg("You picked " .. item .. "!")
  name(lastName) -- display saved name next time
end)


function Example2.nextMessage()
  local node = script:next()
  Example2.displayMessageNode(node)
end

function Example2.selectOption(selection)
  local node = script:select(selection)
  Example2.displayMessageNode(node)
end

function Example2.displayMessageNode(node)
  Example2.displayMode = nil
  if node == nil then
    return -- Erogodic script is over.
  end

  local config = {}
  if node.config ~= nil then
    for k, v in pairs(node.config) do
      config[k] = v
    end
  end
  if node.options then
    Example2.displayMode = 'options'
    config.options = {}
    for i, opt in ipairs(node.options) do
      local onSelect = function()
        Example2.selectOption(opt)
      end
      config.options[i] = {opt, onSelect}
    end
  else
    Example2.displayMode = 'message'
    config.oncomplete = Example2.nextMessage
  end
  Talkies.say(node.name, node.msg, config)
end

function Example2.load()
  Talkies.titleColor = {1, 0.5, 0.5, 0.8}
  Talkies.titleBackgroundColor = {1, 1, 1, 0.2}
  Talkies.titleBorderColor = {1, 1, 1, 0.5}
  Talkies.messageColor = {0.7, 0.7, 1, 0.9}
  Talkies.messageBackgroundColor = {0.5, 0.5, 1, 0.1}
  Talkies.messageBorderColor = {0.5, 0.5, 1, 1}
  Talkies.indicatorCharacter  = " ⊲" -- or ⊳
  Talkies.optionCharacter = "▶"
  Talkies.selectedTextColor = {0.2, 0.2, 0.5, 0.8}
  Talkies.selectedBackgroundColor = {1, 1, 0, 0.8}
  Talkies.selectedWidth = 500
  Talkies.thickness = 2
  Talkies.rounding = 20
  Talkies.padding = 7
  Talkies.textSpeed = 'medium'
  -- The FontStruction “Pixel UniCode” (https://fontstruct.com/fontstructions/show/908795)
  -- by “ivancr72” is licensed under a Creative Commons Attribution license
  -- (http://creativecommons.org/licenses/by/3.0/)
  Talkies.font = love.graphics.newFont("example2/assets/fonts/PixelUniCode.ttf", 32)
  -- Add font fallbacks for Japanese characters
  Talkies.font:setFallbacks(love.graphics.newFont("example2/assets/fonts/JPfallback.ttf", 32))

  -- Audio from bfxr (https://www.bfxr.net/)
  Example2.sndTalk = love.audio.newSource("example2/assets/sfx/talk.wav", "static")
  Example2.sndTalk:setVolume(0.2)
  Example2.sndType = love.audio.newSource("example2/assets/sfx/typeSound.wav", "static")
  Example2.sndType:setVolume(0.1)
  Talkies.talkSound = Example2.sndType
  Talkies.optionOnSelectSound = love.audio.newSource("example2/assets/sfx/optionSelect.wav", "static")
  Talkies.optionOnSelectSound:setVolume(0.1)
  Talkies.optionSwitchSound = love.audio.newSource("example2/assets/sfx/optionSwitch.wav", "static")
  Talkies.optionSwitchSound:setVolume(0.1)
  Example2.imgAvatar = love.graphics.newImage("example2/assets/Obey_Me.png")

  love.graphics.setBackgroundColor(0.0, 0.2, 0.2)

  Example2.nextMessage()
end

function Example2.update(dt)
  if love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift") then
    Example2.advancemessage()
  end
  Talkies.update(dt)
end

function Example2.draw()
  if Talkies.isOpen() == false then
    love.graphics.print('<Game Over>', 20, 20)
  else
    love.graphics.print(
      "Talkies demo (with mouse support) \n" ..
      "  'LMB / Enter': Select option (if present) \n" ..
      "  'RMB / Spacebar': Advance message \n" ..
      "  'Shift': Skip through messages \n" ..
      "  'up/down': Switch options (if present) \n",
      50, 10)
    Talkies.draw()
  end
end

-- Helper to advance message or select option based on current display mode
function Example2.advancemessage()
  if Example2.displayMode == 'message' then
    Talkies.onAction()
  elseif Example2.displayMode == 'options' then
    local currentDialog = Talkies.dialogs:peek()
    if currentDialog == nil then return end

    local currentMessage = currentDialog.messages:peek()
    if currentMessage.paused then
      currentMessage:resume()
    elseif not currentMessage.complete then
      currentMessage:finish()
    end
  end
end

function Example2.keypressed(key)
  if key == "escape" then love.event.quit()
  elseif key == "space" then Example2.advancemessage()
  elseif key == "return" and Example2.displayMode == 'options' then Talkies.onAction()
  elseif key == "up" then Talkies.prevOption()
  elseif key == "down" then Talkies.nextOption()
  end
end

function Example2.mousemoved(x, y)
  local selectedOption = Talkies.optionXY(x, y)
  if selectedOption ~= nil then
    Talkies.selectOption(selectedOption)
  end
end

function Example2.mousepressed(x, y, button)
  if button == 1 then
    local selectedOption = Talkies.optionXY(x, y)
    if selectedOption ~= nil then
      Talkies.selectOption(selectedOption)
      Talkies.onAction()
    end
  elseif button == 2 then
    -- Right click to advance message
    Example2.advancemessage()
  end
end


return Example2
