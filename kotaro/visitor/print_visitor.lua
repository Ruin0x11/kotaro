local print_visitor = {}

function print_visitor:new(stream)
   local o = setmetatable({}, { __index = print_visitor })
   o.stream = stream or { stream = io, write = function(t, ...) t.stream.write(...) end }
   o.indent = 0
   return o
end

function print_visitor:print_node(node)
   self.stream:write(string.format("%s%s\n", string.rep(' ', self.indent), tostring(node)))
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
