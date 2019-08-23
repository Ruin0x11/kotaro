local line_numbering_visitor = {}

function line_numbering_visitor:new()
   return setmetatable({ line = 1, column = 0, offset = 0 }, { __index = line_numbering_visitor })
end

function line_numbering_visitor:visit_leaf(node)
   local prefix = node:prefix()

   local offset = 0

   for c in string.gmatch(prefix, ".") do
      if c == "\n" then
         self.line = self.line + 1
         self.column = 0
      else
         self.column = self.column + 1
      end
      offset = offset + 1
   end

   offset = offset + #node.value

   node.line = self.line
   node.column = self.column
   node.offset = self.offset

   self.column = self.column + #node.value
   self.offset = self.offset + offset
end

function line_numbering_visitor:visit_node(node, visit)
   visit(self, node, visit)
end

return line_numbering_visitor
