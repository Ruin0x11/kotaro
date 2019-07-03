local socket = require("socket")

local stopwatch = require("class").class("stopwatch")

function stopwatch:init()
   self.time = socket.gettime()
end

function stopwatch:measure()
   local new = socket.gettime()
   local result = new - self.time
   self.time = new
   return result
end

function stopwatch:p(t)
   t = t or ""
   local m = self:measure()
   print(string.format("[%s] %02.02f", t, m))
   return m
end

return stopwatch
