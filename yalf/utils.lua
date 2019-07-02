local utils = {}

function utils.set(t)
   local s = {}
   for _, v in ipairs(t) do
      s[v] = true
   end
   return s
end

function utils.copy(t)
   local n = {}
   for k, v in pairs(t) do
      n[k] = v
   end
   return n
end

return utils
