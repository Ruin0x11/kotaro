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

-- Returns an IO stream suitable for use with io.write() which writes
-- its output to a string.
function utils.string_io()
   return {
      stream = "",
      write = function(self, s)
         self.stream = self.stream .. s
      end
   }
end

-- from penlight
local function cycle_aware_copy(t, cache)
    if type(t) ~= 'table' then return t end
    if cache[t] then return cache[t] end
    local res = {}
    cache[t] = res
    local mt = getmetatable(t)
    for k,v in pairs(t) do
        k = cycle_aware_copy(k, cache)
        v = cycle_aware_copy(v, cache)
        res[k] = v
    end
    setmetatable(res,mt)
    return res
end

function utils.deepcopy(t)
    return cycle_aware_copy(t,{})
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
