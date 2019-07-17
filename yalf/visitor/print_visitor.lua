local print_visitor = {}

-- from inspect.lua
local function smart_quote(str)
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

local function escape(str)
  return (str:gsub("\\", "\\\\")
             :gsub("(%c)%f[0-9]", long_control_char_escapes)
             :gsub("%c", short_control_char_escapes))
end

local function dump_node(node)
   if node:type() == "leaf" then
      return string.format("%s(%s) [line=%d, column=%d, prefix='%s']",
                           string.upper(node.leaf_type), smart_quote(tostring(node.value)), node.line, node.column, escape(node:prefix_to_string()))
   else
      return string.format("%s [%d children]",
                           node[1], #node-1)
   end
end

function print_visitor:new(stream)
   local o = setmetatable({}, { __index = print_visitor })
   o.stream = stream or { stream = io, write = function(t, ...) t.stream.write(...) end }
   o.indent = 0
   return o
end

function print_visitor:print_node(node)
   self.stream:write(string.format("%s%s\n", string.rep(' ', self.indent), dump_node(node)))
end

function print_visitor:visit_node(node, visit)
   self:print_node(node)
   self.indent = self.indent + 2
   visit(self, node, visit)
   self.indent = self.indent - 2
end

function print_visitor:visit_leaf(leaf)
   self:print_node(leaf)
end

return print_visitor
