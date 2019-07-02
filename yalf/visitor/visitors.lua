local nodes = require("yalf.parser.nodes")
local Node = nodes.node
local Leaf = nodes.leaf

local class = require("thirdparty.pl.class")

local base_visitor = {}

function base_visitor:visit(node)
   if node:is_a(Leaf) then
      self:visit_leaf(node)
   else
      self:visit_node(node)
   end
end

function base_visitor:visit_leaf(leaf)
   error("unimplemented")
end

function base_visitor:visit_node(node)
   for _, v in ipairs(node.children) do
      self:visit(v)
   end
end

local print_visitor = class(base_visitor)

function print_visitor:_init(stream)
   self.stream = stream or { stream = io, write = function(t, ...) t.stream.write(...) end }
   self.indent = 0
end

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

function print_visitor:print_node(node)
   self.stream:write(string.format("%s%s\n", string.rep(' ', self.indent), dump_node(node)))
end

do
   local super = base_visitor.visit_node
   function print_visitor:visit_node(node)
      self:print_node(node)
      self.indent = self.indent + 2
      super(self, node)
      self.indent = self.indent - 2
   end
end

function print_visitor:visit_leaf(leaf)
   self:print_node(leaf)
end

return { print_visitor = print_visitor }
