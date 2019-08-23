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

function utils.is_valid_lua_ident(str)
   return type(str) == "string" and string.match(str, "^[_%a][_%w]*$")
end

function utils.quote_string(str)
  if str:match('"') and not str:match("'") then
    return "'" .. str .. "'"
  end
  return '"' .. str:gsub('"', '\\"') .. '"'
end

local short_control_char_escapes = {
  ["\a"] = "\\a",  ["\b"] = "\\b", ["\f"] = "\\f", ["\n"] = "\\n",
  ["\r"] = "\\r",  ["\t"] = "\\t", ["\v"] = "\\v"
}
local long_control_char_escapes = {} -- \a => nil, \0 => \000, 31 => \031
for i=0, 31 do
  local ch = string.char(i)
  if not short_control_char_escapes[ch] then
    short_control_char_escapes[ch] = "\\"..i
    long_control_char_escapes[ch]  = string.format("\\%03d", i)
  end
end

function utils.escape_string(str)
  return (str:gsub("\\", "\\\\")
             :gsub("(%c)%f[0-9]", long_control_char_escapes)
             :gsub("%c", short_control_char_escapes))
end

function utils.table_length(tbl)
   local i = 0
   for _, _ in pairs(tbl) do
      i = i + 1
   end
   return i
end

function utils.tostring_raw(tbl)
   if type(tbl) ~= "table" then
      return tostring(tbl)
   end

   local mt = getmetatable(tbl)
   setmetatable(tbl, {})
   local s = tostring(tbl)
   setmetatable(tbl, mt)
   return s
end

local string_buffer = {}
function string_buffer:append(s)
   table.insert(self, s)
   for i=#self-1, 1, -1 do
      if string.len(self[i]) > string.len(self[i+1]) then
         break
      end
      self[i] = self[i] .. table.remove(self)
   end
end
function string_buffer:__tostring()
   return table.concat(self)
end

function utils.string_buffer()
   return setmetatable({""}, { __index = string_buffer, __tostring = string_buffer.__tostring })
end

return utils
