local line_numbering_visitor = {}

function line_numbering_visitor:new()
   return setmetatable({ line = 1, column = 0 }, { __index = line_numbering_visitor })
end

function line_numbering_visitor:visit_leaf(node)
   local prefix = node:prefix()

   for _, c in ipairs(prefix) do
      if c.Data == "\n" then
         self.line = self.line + 1
         self.column = 0
      else
         self.column = self.column + 1
      end
   end

   node.line = self.line
   node.column = self.column

   self.column = self.column + #node.value
end

function line_numbering_visitor:visit_node(node, visit)
   visit(self, node, visit)
end

return line_numbering_visitor
