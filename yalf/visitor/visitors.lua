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

local function dump_node(node)
   if node:is_a(Leaf) then
      return string.format("Leaf(%s) [line=%d, column=%d, prefix='%s']",
                           node.type, node.line, node.column, node:get_prefix())
   elseif node:is_a(Node) then
      return string.format("Node(%s) [%d children]",
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
