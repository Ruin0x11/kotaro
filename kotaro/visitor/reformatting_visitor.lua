local Codegen = require("kotaro.parser.codegen")

local reformatting_visitor = {}

local function split_and_indent(leaf, indent)
   leaf:set_prefix("\n" .. string.rep(" " , indent))
end

local step = 3

function reformatting_visitor:new()
   return setmetatable({ indent = 0, line = 1, column = 0, first = true }, { __index = reformatting_visitor })
end
function reformatting_visitor:visit_leaf(node)
   local do_split = node.must_split or not node.split_penalty or node.split_penalty < 1000 * 1000

   if do_split and false then
      split_and_indent(node, self.indent)
   else
      local spaces = node.spaces_before or 1
      node:set_prefix(string.rep(" ", spaces))

      if node.is_last_leaf_of_statement then
         local statement_list, index = node:find_parent_of_type("statement_list")
         local l_semicolon = Codegen.gen_symbol(";")
         l_semicolon.split_penalty = 1000 * 1000
         l_semicolon.spaces_before = 0
         table.insert(statement_list, index+1, l_semicolon)
      end
   end

   for _, c in ipairs(node:prefix()) do
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
function reformatting_visitor:visit_node(node, visit)
   local indent = self.indent
   if node.is_block then
      if self.first then
         indent = 0
         self.first = false
      else
         indent = self.indent + step
      end
   elseif node.trailer_start then
      if node.trailer_head:was_split() then
         indent = node.trailer_start:left_boundary() + step
      else
         indent = node.trailer_start:right_boundary()
      end
   end
   local before = self.indent
   self.indent = indent
   visit(self, node, visit)
   self.indent = before
end

return reformatting_visitor
