local utils = {}

function utils.set(t)
   local s = {}
   for _, v in ipairs(t) do
      s[v] = true
   end
   return s
end

return utils
