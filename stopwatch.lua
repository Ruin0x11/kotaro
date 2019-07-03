function math.sign(v)
   return (v >= 0 and 1) or -1
end

function math.round(v, digits)
   digits = digits or 0
   local bracket = 1 / (10 ^ digits)
   return math.floor(v/bracket + math.sign(v) * 0.5) * bracket
end

local socket = require("socket")

local stopwatch = require("pl.class")()

function stopwatch:_init()
   self.time = socket.gettime()
   self.framerate = 60
end

function stopwatch:measure(precision)
   local new = socket.gettime()
   local result = new - self.time
   self.time = new
   return math.round(result * 1000, precision or 5)
end

local function msecs_to_frames(msecs, framerate)
   local msecs_per_frame = (1 / framerate) * 1000
   local frames = msecs / msecs_per_frame
   return frames
end

function stopwatch:measure_and_format(text)
   if text then
      text = string.format("[%s]", text)
   else
      text = ""
   end

   local msecs = self:measure()
   return string.format("%s\t%02.02fms\t(%02.02f frames)",
                        text,
                        msecs,
                        msecs_to_frames(msecs, self.framerate))
end

function stopwatch:p(text)
   print(self:measure_and_format(text))
end

function stopwatch:bench(f, ...)
   self:measure()
   f(...)
   return self:measure_and_format()
end


return stopwatch
