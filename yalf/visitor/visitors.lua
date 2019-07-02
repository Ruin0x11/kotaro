local nodes = require("yalf.parser.nodes")
local Node = nodes.node
local Leaf = nodes.leaf

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
   if node:is_a(Leaf) then
      return string.format("%s(%s) [line=%d, column=%d, prefix='%s']",
                           string.upper(node.type), smart_quote(tostring(node.value)), node.line, node.column, escape(node:prefix_to_string()))
   elseif node:is_a(Node) then
      return string.format("%s [%d children]",
                           node.type, #node.children)
   else
      error("unknown node")
   end
end


local visitor = {}

function visitor.visit_node(v, node, visit)
   for _, child in ipairs(node.children) do
      visitor.visit(v, child)
   end
end

function visitor.visit(v, node)
   if node:is_a(Leaf) then
      v:visit_leaf(node)
   else
      v:visit_node(node, visitor.visit_node)
   end
end

local print_visitor = {}

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

local refactoring_visitor = {}

function refactoring_visitor:new(refactorings)
   local o = setmetatable({}, { __index = refactoring_visitor })
   o.refactorings = refactorings
   return o
end

function refactoring_visitor:visit_leaf(node)
   for _, v in ipairs(self.refactorings) do
      if v:applies_to(node) then
         v:execute(node)
      end
   end
end

function refactoring_visitor:visit_node(node, visit)
   for _, v in ipairs(self.refactorings) do
      if v:applies_to(node) then
         v:execute(node)
      end
   end

   visit(self, node, visit)
end

return { visitor = visitor, print_visitor = print_visitor, refactoring_visitor = refactoring_visitor }
