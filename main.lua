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

function love.mousemoved(x, y)
  Example.mousemoved(x, y)
end

function love.mousepressed(x, y, button)
  Example.mousepressed(x, y, button)
end

function love.draw()
  Example.draw()
end
