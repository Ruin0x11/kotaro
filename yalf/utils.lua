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

function utils.replace_table(tbl, other)
   if tbl == other then
      return tbl
   end

   for k, _ in pairs(tbl) do
      tbl[k] = nil
   end

   for k, v in pairs(other) do
      tbl[k] = v
   end

   local mt = getmetatable(other)
   setmetatable(tbl, mt)

   return tbl
end

return utils
