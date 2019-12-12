local tree_utils = require("kotaro.parser.tree_utils")

local identify_containers_visitor = {}

function identify_containers_visitor:new()
   return setmetatable({ scopes = {} }, { __index = identify_containers_visitor })
end

function identify_containers_visitor:visit_leaf(node)
end

local function mark_block(node, block_start, block_end)
   local cb = function(n)
      n.block_start = block_start
      n.block_end = block_end
   end
   block_start.is_block_start = true
   block_end.is_block_end = true
   tree_utils.each_leaf(node, cb)
end

function identify_containers_visitor:visit_node(node, visit)
   if node:type() == "constructor_expression" then
      for _, child in ipairs(node:children()) do
         child:first_leaf().opening_bracket = node:first_leaf()
      end
      node:first_leaf().matching_bracket = node:last_leaf()
      node:last_leaf().matching_bracket = node:first_leaf()

      node:first_leaf().is_block_start = true
      node:last_leaf().is_block_end = true

      assert(node:first_leaf().matching_bracket.value == "}")
      assert(node:last_leaf().matching_bracket.value == "{")
   end
   if node:type() == "function_parameters_and_body" then
      -- mark the parameter list between '(' and ')' as a block
      node[4].function_start = node.parent[2]
      node[2].matching_bracket = node[4]
      node[4].matching_bracket = node[2]
      mark_block(node, node[2], node[4])
   end
   if node:type() == "expression" then
      if node:is_unary() then
         node:operator().is_unary_op = true
      elseif node:is_binary() then
         node:operator().is_binary_op = true
      end
   end
   if node:type() == "suffixed_expression" then
      for i = 2, #node do
         local leaf = node[i]:first_leaf()
         if leaf then
            leaf.first_suffix = node[2]
         end
      end
   end
   if node:type() == "if_block" then
      local if_start = node[2]
      local if_clause_start
      local if_clause
      for _, v in node:iter_rest() do
         if v.value == "if" or v.value == "elseif" then
            if if_clause then
               if_clause.next_if_clause = v
               if_clause = nil
            end
            if_clause_start = v
         elseif v.value == "then" then
            v.if_clause_start = if_clause_start
            if_clause_start.if_clause_end = v
            if_clause = v
            if_clause_start = nil
         elseif v.value == "end" and if_clause then
            if_clause.next_if_clause = v
         end
         if v.value ~= "if" then
            v.if_start = if_start
         end
      end
   end
   if tree_utils.is_block(node) then
      local block_start = node:first_leaf()
      local block_end = node:last_leaf()
      mark_block(node, block_start, block_end)
   end
   visit(self, node, visit)
end

return identify_containers_visitor
