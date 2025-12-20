-- local Example = require 'example1.example1'
local Example = require 'example2.example2'

function love.load()
  Example.load()
end

function love.update(dt)
  Example.update(dt)
end

function love.keypressed(key)
  Example.keypressed(key)
end

function love.draw()
  Example.draw()
end
