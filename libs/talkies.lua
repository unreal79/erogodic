--
-- talkies v.0.1.0
--
-- Copyright (c) 2017-2020 twentytwoo, tanema, Talkies contributors
--
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.


---@class utf8lib
local utf8 = require("utf8")

--  Substring function which gets a substring of `str` from character indices `start` to `stop`
--  Automatically calculates correct byte offsets
--  If `start` is nil, starts from index `1`
--  If `stop` is nil, stops at end of string
--
--    Modified from code by lhf
--    https://stackoverflow.com/a/43139063
function utf8.sub(str, start, stop)
    local strLength = utf8.len(str)
    local start = math.min(start or 1, strLength)
    start = utf8.offset(str, start)
    local stop = stop or strLength
    stop = math.min(stop, strLength)
    if stop == -1 then
        stop = strLength
    else
        stop = utf8.offset(str, stop + 1) - 1
    end
    return string.sub(str, start, stop)
end

-- Play a sound with optional pitch shift
local function playSound(sound, pitch)
    if type(sound) == "userdata" then
        sound:setPitch(pitch or 1)
        sound:play()
    end
end

-- Parse speed setting into time per character
local function parseSpeed(speed)
    if speed == "instant" then
        return -1.0
    elseif speed == "fast" then
        return 0.01
    elseif speed == "medium" then
        return 0.04
    elseif speed == "slow" then
        return 0.08
    else
        assert(tonumber(speed), "setSpeed() - Expected number, got " .. tostring(speed))
        return speed
    end
end

local msgFifo = nil -- Message FIFO

-- Fifo class
local Fifo = {}
local optionsXYWH = {}

-- Create a new Fifo instance
function Fifo.new()
    optionsXYWH = {}
    return setmetatable({ first = 1, last = 0 }, { __index = Fifo })
end

-- Peek at the first value in the fifo without removing it
function Fifo:peek()
    return self[self.first]
end

-- Get the number of items in the fifo
function Fifo:len()
    return (self.last + 1) - self.first
end

-- Add a value to the end of the fifo
function Fifo:push(value)
    self.last = self.last + 1
    self[self.last] = value
end

-- Remove and return the first value from the fifo
function Fifo:pop()
    if self.first > self.last then return end

    local value = self[self.first]
    self[self.first] = nil
    self.first = self.first + 1
    return value
end

-- Typer class
local Typer = {}

-- Create a new Typer instance
function Typer.new(msg, speed)
    local timeToType = parseSpeed(speed)

    local strip = string.gsub(msg, "\n", "")

    return setmetatable({
        msg = msg,
        complete = false,
        paused = false,
        timer = timeToType,
        max = timeToType,
        position = 1,
        strip = strip,
    }, { __index = Typer })
end

-- Resume typing after a pause
function Typer:resume()
    if not self.paused then return end

    self.msg = self.msg:gsub("%-%-", "", 1)
    self.strip = self.strip:gsub("%-%-", "", 1)
    self.paused = false
end

-- Finish typing the message immediately
function Typer:finish()
    if self.complete then return end

    self.msg = self.msg:gsub("%-%-", "")
    self.strip = self.strip:gsub("%-%-", "")
    self.position = utf8.len(self.strip)
    self.complete = true
end

-- Update the typer
--- Returns true if currently busy typing a character
function Typer:update(dt)
    local typed = false

    if self.complete then return typed end

    if not self.paused then
        self.timer = self.timer - dt
        while not self.paused and not self.complete and self.timer <= 0 do
            typed = utf8.sub(self.strip, self.position, self.position) ~= " "
            self.position = self.position + 1

            self.timer = self.timer + self.max

            self.complete = self.position >= utf8.len(self.strip)

            self.paused = utf8.sub(self.strip, self.position + 1, self.position + 2) == "--"
        end
    end

    return typed
end

-- Talkies default settings table
local Talkies = {
    _VERSION               = '0.0.3',
    _URL                   = 'https://github.com/unreal79/talkies',
    _DESCRIPTION           = 'A simple messagebox system for LÖVE',

    -- Theme
    indicatorCharacter     = ">",
    optionCharacter        = "-",
    height                 = nil,
    padding                = 10,
    talkSound              = nil,
    optionSwitchSound      = nil,
    inlineOptions          = true,

    imageOnLeft            = true,

    titleColor             = { 1, 1, 1, 1 },
    titleBackgroundColor   = nil,
    titleBorderColor       = nil,
    titleOnLeft            = true,
    messageColor           = { 1, 1, 1, 1 },
    messageBackgroundColor = { 0, 0, 0, 0.8 },
    messageBorderColor     = nil,
    selectedTextColor       = { 0.2, 0.2, 0.2, 0.8 },
    selectedBackgroundColor = { 1, 1, 1, 0.8 },
    selectedWidth           = 300,

    rounding               = 0,
    thickness              = 0,

    textSpeed              = 1 / 60,
    font                   = love.graphics.newFont(),

    typedNotTalked         = true,
    pitchValues            = { 0.7, 0.8, 1.0, 1.2, 1.3 },

    indicatorTimer         = 0,
    indicatorDelay         = 3,
    showIndicator          = false,
    dialogs                = Fifo.new(),
}

-- Create and show a new dialog
function Talkies.say(title, messages, config)
    config = config or {}
    if type(messages) ~= "table" then
        messages = { messages }
    end

    msgFifo = Fifo.new()

    for i = 1, #messages do
        msgFifo:push(Typer.new(messages[i], config.textSpeed or Talkies.textSpeed))
    end

    -- Insert the Talkies.new into its own instance (table)
    local newDialog = {
        title              = title or "",
        messages           = msgFifo,
        image              = config.image,
        imageOnLeft        = config.imageOnLeft == nil and Talkies.imageOnLeft or config.imageOnLeft,
        titleOnLeft        = config.titleOnLeft == nil and Talkies.titleOnLeft or config.titleOnLeft,
        options            = config.options,
        onstart            = config.onstart or function(dialog) end,
        onmessage          = config.onmessage or function(dialog, left) end,
        oncomplete         = config.oncomplete or function(dialog) end,

        -- theme
        messageBackgroundColor = config.messageBackgroundColor == nil and Talkies.messageBackgroundColor or config.messageBackgroundColor,
        messageColor       = config.messageColor or Talkies.messageColor,
        selectedTextColor  = config.selectedTextColor or Talkies.selectedTextColor,
        selectedBackgroundColor = config.selectedBackgroundColor or Talkies.selectedBackgroundColor,
        selectedWidth      = config.selectedWidth or Talkies.selectedWidth,
        indicatorCharacter = config.indicatorCharacter or Talkies.indicatorCharacter,
        optionCharacter    = config.optionCharacter or Talkies.optionCharacter,
        height             = config.height or Talkies.height,
        padding            = config.padding or Talkies.padding,
        rounding           = config.rounding or Talkies.rounding,
        thickness          = config.thickness or Talkies.thickness,
        talkSound          = config.talkSound == nil and Talkies.talkSound or config.talkSound,
        optionSwitchSound  = config.optionSwitchSound or Talkies.optionSwitchSound,
        inlineOptions      = config.inlineOptions == nil and Talkies.inlineOptions or config.inlineOptions,
        font               = config.font or Talkies.font,
        fontHeight         = (config.font or Talkies.font):getHeight(" "),
        typedNotTalked     = config.typedNotTalked == nil and Talkies.typedNotTalked or config.typedNotTalked,
        pitchValues        = config.pitchValues or Talkies.pitchValues,

        optionIndex        = 1,

        showOptions        = function(dialog) return dialog.messages:len() == 1 and type(dialog.options) == "table" end,
        isShown            = function(dialog) return Talkies.dialogs:peek() == dialog end
    }

    newDialog.titleBackgroundColor = config.titleBackgroundColor or Talkies.titleBackgroundColor or
        newDialog.messageBackgroundColor
    newDialog.titleColor = config.titleColor or Talkies.titleColor or newDialog.messageColor
    newDialog.messageBorderColor = config.messageBorderColor or Talkies.messageBorderColor or
        newDialog.messageBackgroundColor
    newDialog.titleBorderColor = config.titleBorderColor or Talkies.titleBorderColor or newDialog.messageBorderColor

    Talkies.dialogs:push(newDialog)
    if Talkies.dialogs:len() == 1 then
        Talkies.dialogs:peek():onstart()
    end

    return newDialog
end

-- Update the dialog system
function Talkies.update(dt)
    local currentDialog = Talkies.dialogs:peek()
    if currentDialog == nil then return end

    local currentMessage = currentDialog.messages:peek()

    if currentMessage.paused or currentMessage.complete then
        Talkies.indicatorTimer = Talkies.indicatorTimer + (10 * dt)
        if Talkies.indicatorTimer > Talkies.indicatorDelay then
            Talkies.showIndicator = not Talkies.showIndicator
            Talkies.indicatorTimer = 0
        end
    else
        Talkies.showIndicator = false
    end

    if currentMessage:update(dt) then
        if currentDialog.typedNotTalked then
            playSound(currentDialog.talkSound)
        elseif not currentDialog.talkSound:isPlaying() then
            local pitch = currentDialog.pitchValues[math.random(#currentDialog.pitchValues)]
            playSound(currentDialog.talkSound, pitch)
        end
    end
end

-- Advance to the next message
function Talkies.advanceMsg()
    local currentDialog = Talkies.dialogs:peek()
    if currentDialog == nil then return end

    currentDialog:onmessage(currentDialog.messages:len() - 1)
    if currentDialog.messages:len() == 1 then
        Talkies.dialogs:pop()
        currentDialog:oncomplete()
        if Talkies.dialogs:len() == 0 then
            Talkies.clearMessages()
        else
            Talkies.dialogs:peek():onstart()
        end
    end
    currentDialog.messages:pop()
end

-- Check if a dialog is currently open
function Talkies.isOpen()
    return Talkies.dialogs:peek() ~= nil
end

-- Draw the current dialog
function Talkies.draw()
    local currentDialog = Talkies.dialogs:peek()
    if currentDialog == nil then return end

    -- love.graphics.push()

    -- local windowWidth, windowHeight = love.graphics.getDimensions()
    -- local canvas = love.graphics.getCanvas()
    -- if canvas then
    --     windowWidth, windowHeight = canvas:getDimensions()
    -- end

    local windowWidth, windowHeight = 1920, 1080

    love.graphics.setLineWidth(currentDialog.thickness)

    -- message box
    local boxW = windowWidth - (2 * currentDialog.padding)
    local boxH = currentDialog.height or (windowHeight / 3) - (2 * currentDialog.padding)
    local boxX = currentDialog.padding
    local boxY = windowHeight - (boxH + currentDialog.padding)

    -- image
    local imgX, imgY, imgW, imgScale = boxX + currentDialog.padding, boxY + currentDialog.padding, 0, 0
    if currentDialog.image ~= nil then
        imgScale = (boxH - (currentDialog.padding * 2)) / currentDialog.image:getHeight()
        imgW = currentDialog.image:getWidth() * imgScale

        if currentDialog.imageOnLeft == false then
            imgX = boxX + boxW - currentDialog.padding - imgW
        end
    end

    -- title box
    local textX, textY
    if currentDialog.image ~= nil and currentDialog.imageOnLeft ~= false then
        textX = imgX + imgW + currentDialog.padding
    else
        -- no image OR image is on the right
        textX = boxX + (2 * currentDialog.padding)
    end
    textY = boxY + 4

    love.graphics.setFont(currentDialog.font)

    if currentDialog.title ~= "" then
        local titleBoxW = currentDialog.font:getWidth(currentDialog.title) + (2 * currentDialog.padding)
        local titleBoxH = currentDialog.fontHeight + currentDialog.padding
        local titleBoxY = boxY - titleBoxH - (currentDialog.padding / 2)
        local titleBoxX = boxX
        if currentDialog.titleOnLeft == false then
            titleBoxX = boxX + boxW - titleBoxW
        end
        local titleX, titleY = titleBoxX + currentDialog.padding, titleBoxY + currentDialog.padding / 2

        -- Message title
        love.graphics.setColor(currentDialog.titleBackgroundColor)
        love.graphics.rectangle("fill", titleBoxX, titleBoxY, titleBoxW, titleBoxH, currentDialog.rounding,
            currentDialog.rounding)
        if currentDialog.thickness > 0 then
            love.graphics.setColor(currentDialog.titleBorderColor)
            love.graphics.rectangle("line", titleBoxX, titleBoxY, titleBoxW, titleBoxH, currentDialog.rounding,
                currentDialog.rounding)
        end
        love.graphics.setColor(currentDialog.titleColor)
        love.graphics.print(currentDialog.title, titleX, titleY)
    end

    -- Main message box
    love.graphics.setColor(currentDialog.messageBackgroundColor)
    love.graphics.rectangle("fill", boxX, boxY, boxW, boxH, currentDialog.rounding, currentDialog.rounding)
    if currentDialog.thickness > 0 then
        love.graphics.setColor(currentDialog.messageBorderColor)
        love.graphics.rectangle("line", boxX, boxY, boxW, boxH, currentDialog.rounding, currentDialog.rounding)
    end

    -- Message avatar
    if currentDialog.image ~= nil then
        -- love.graphics.push()
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(currentDialog.image, imgX, imgY, 0, imgScale, imgScale)
        -- love.graphics.pop()
    end

    -- Message text
    love.graphics.setColor(currentDialog.messageColor)
    local textW = boxW - imgW - (4 * currentDialog.padding)
    local textH = currentDialog.font:getHeight()

    local currentMessage = currentDialog.messages:peek()
    local _, modmsg = currentDialog.font:getWrap(currentMessage.msg, textW)

    local tempPosition = 1
    local lineNum = 1

    while tempPosition < currentMessage.position and utf8.len(currentMessage.strip) > 0 do
        local displayLine = modmsg[lineNum]
        local positionAdd = math.min(currentMessage.position - tempPosition + 1, utf8.len(displayLine))
        tempPosition = tempPosition + positionAdd
        local display = utf8.sub(displayLine, 1, positionAdd)
        love.graphics.print(display, textX, textY + textH * (lineNum - 1) + currentDialog.padding / 2)
        lineNum = lineNum + 1
    end

    -- Message options (when shown)
    if currentDialog:showOptions() and currentMessage.complete then
        local optionLeftPad = currentDialog.font:getWidth(currentDialog.optionCharacter .. " ")
        if currentDialog.inlineOptions then
            local optionsY = textY + currentDialog.font:getHeight() * #modmsg

            love.graphics.setColor(currentDialog.selectedBackgroundColor)
            love.graphics.rectangle("fill",
                textX+currentDialog.padding-1, optionsY+(currentDialog.optionIndex-1)*currentDialog.fontHeight,
                currentDialog.selectedWidth, currentDialog.fontHeight)

            optionsXYWH = {}
            for k, option in pairs(currentDialog.options) do
                if k == currentDialog.optionIndex then
                    love.graphics.setColor(currentDialog.selectedTextColor)
                else
                    love.graphics.setColor(currentDialog.messageColor)
                end
                love.graphics.print(option[1], optionLeftPad + textX + currentDialog.padding,
                    optionsY + (k - 1) * currentDialog.fontHeight)
                optionsXYWH[k] = {}
                optionsXYWH[k].x = optionLeftPad + textX + currentDialog.padding
                optionsXYWH[k].y = optionsY + (k - 1)*currentDialog.fontHeight
                optionsXYWH[k].w = currentDialog.selectedWidth
                optionsXYWH[k].h = currentDialog.fontHeight
            end
            love.graphics.setColor(currentDialog.selectedTextColor)
            love.graphics.print(
                currentDialog.optionCharacter .. " ",
                textX + currentDialog.padding,
                optionsY + ((currentDialog.optionIndex - 1) * currentDialog.fontHeight))
        else
            local optionWidth = 0
            for k, option in pairs(currentDialog.options) do
                local newText = ((currentDialog.optionIndex == k and currentDialog.optionCharacter) or " ") ..
                    " " .. option[1]
                optionWidth = math.max(optionWidth, currentDialog.font:getWidth(newText ..
                        ((currentDialog.optionIndex ~= k and currentDialog.optionCharacter) or " ")) + 20)
            end

            local optionsH = (currentDialog.font:getHeight() * #currentDialog.options)
            local optionsX = math.floor((windowWidth / 2) - (optionWidth / 2))
            local optionsY = math.floor((windowHeight / 3) - (optionsH / 2))

            love.graphics.setColor(currentDialog.messageBackgroundColor)
            love.graphics.rectangle("fill", optionsX - currentDialog.padding, optionsY - currentDialog.padding,
                optionWidth + currentDialog.padding * 2, optionsH + currentDialog.padding * 2,
                currentDialog.rounding, currentDialog.rounding)

            if currentDialog.thickness > 0 then
                love.graphics.setColor(currentDialog.messageBorderColor)
                love.graphics.rectangle("line", optionsX - currentDialog.padding, optionsY - currentDialog.padding,
                    optionWidth + currentDialog.padding * 2, optionsH + currentDialog.padding * 2,
                    currentDialog.rounding, currentDialog.rounding)
            end

            love.graphics.setColor(currentDialog.selectedBackgroundColor)
            love.graphics.rectangle("fill", optionsX, optionsY+(currentDialog.optionIndex-1)*currentDialog.fontHeight,
                optionWidth, currentDialog.fontHeight)
            optionsXYWH = {}
            for k, option in pairs(currentDialog.options) do
                if currentDialog.optionIndex == k then
                    love.graphics.setColor(currentDialog.selectedTextColor)
                else
                    love.graphics.setColor(currentDialog.messageColor)
                end
                love.graphics.print(option[1], optionsX + optionLeftPad,
                    optionsY + (k - 1) * currentDialog.fontHeight)
                optionsXYWH[k] = {}
                optionsXYWH[k].x = optionsX
                optionsXYWH[k].y = optionsY + (k - 1) * currentDialog.fontHeight
                optionsXYWH[k].w = optionWidth
                optionsXYWH[k].h = currentDialog.fontHeight
            end
        end
    end

    -- Next message/continue indicator
    if Talkies.showIndicator then
        love.graphics.print(currentDialog.indicatorCharacter, boxX + boxW - (2.5 * currentDialog.padding),
            boxY + boxH - currentDialog.fontHeight)
    end

    -- love.graphics.pop()

    -- Reset color so other draw operations won't be affected
    love.graphics.setColor(1, 1, 1, 1)
end

-- Select previous option
function Talkies.prevOption()
    local currentDialog = Talkies.dialogs:peek()
    if currentDialog == nil or not currentDialog:showOptions() then return end

    currentDialog.optionIndex = currentDialog.optionIndex - 1
    if currentDialog.optionIndex < 1 then
        currentDialog.optionIndex = #currentDialog.options
    end
    playSound(currentDialog.optionSwitchSound)
end

-- Select next option
function Talkies.nextOption()
    local currentDialog = Talkies.dialogs:peek()
    if currentDialog == nil or not currentDialog:showOptions() then return end

    currentDialog.optionIndex = currentDialog.optionIndex + 1
    if currentDialog.optionIndex > #currentDialog.options then
        currentDialog.optionIndex = 1
    end
    playSound(currentDialog.optionSwitchSound)
end

-- Select option by index (1-based)
---- Used in mouse handling
function Talkies.selectOption(index)
    local currentDialog = Talkies.dialogs:peek()
    if currentDialog == nil or not currentDialog:showOptions() or index == currentDialog.optionIndex then
        return
    end

    currentDialog.optionIndex = index
    playSound(currentDialog.optionSwitchSound)
end

-- Get option index at given x,y coordinates (or nil if none)
---- Used in mouse handling
function Talkies.optionXY(x, y)
    local currentDialog = Talkies.dialogs:peek()
    if currentDialog == nil then return nil end

    local currentMessage = currentDialog.messages:peek()
    if not currentDialog:showOptions() or not currentMessage.complete then
        return nil
    end

    for i, option in ipairs(optionsXYWH) do
        if x >= option.x and x < option.x + option.w
                and y >= option.y and y < option.y + option.h then
            return i
        end
    end

    return nil
end

-- Handle action input (advance message or select option)
function Talkies.onAction()
    local currentDialog = Talkies.dialogs:peek()
    if currentDialog == nil then return end

    local currentMessage = currentDialog.messages:peek()

    if currentMessage.paused then
        currentMessage:resume()
    elseif not currentMessage.complete then
        currentMessage:finish()
    else
        if currentDialog:showOptions() then
            currentDialog.options[currentDialog.optionIndex][2]() -- Execute the selected function
            playSound(currentDialog.optionSwitchSound)
        end
        Talkies.advanceMsg()
    end
end

-- Clear all messages
function Talkies.clearMessages()
    Talkies.dialogs = Fifo.new()
end

return Talkies
