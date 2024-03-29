local tree_utils = require("kotaro.parser.tree_utils")
local split_penalty = require ("kotaro.split_penalty")

local split_penalty_visitor = {}

local function set_penalty(node, penalty)
   local leaf
   if node:is_leaf() then
      leaf = node
   else
      leaf = node:first_leaf()
   end
   if not leaf then return end

   leaf.split_penalty = split_penalty[penalty]
   assert(leaf.split_penalty)
end

local function increase_penalty(node, penalty)
   local leaf
   if node:is_leaf() then
      leaf = node
   else
      leaf = node:first_leaf()
   end
   if not leaf then return end

   leaf.split_penalty = (leaf.split_penalty or 0) + split_penalty[penalty]
end

local function set_spaces_before(node, spaces_before)
   local leaf
   if node:is_leaf() then
      leaf = node
   else
      leaf = node:first_leaf()
   end
   if not leaf then return end

   leaf.spaces_required_before = spaces_before
end

local function set_must_split(node)
   local leaf
   if node:is_leaf() then
      leaf = node
   else
      leaf = node:first_leaf()
   end
   if not leaf then return end

   leaf.must_split = true
end

local function set_unbreakable(node, spaces_before)
   set_penalty(node, "unbreakable")
   if spaces_before then
      set_spaces_before(node, spaces_before)
   end
end

-- Marks the tokens in [start, finish] as belonging to a block. If
-- anything gets indented within the block, the indent calculation
-- will also indent all the tokens in [start+1, finish].
local function mark_block(node, start, finish)
   node.blocks = node.blocks or {}
   table.insert(node.blocks, { start, finish })
end

-- marks the nodes in [start, finish] as dependent on the node at
-- `start` for indent.
local function add_trailer(node, start, finish)
   finish = finish or #node

   -- <tbl>:call():call2()
   local start_node = node[start]

   -- tbl<:call>():call2()
   local head = node[start+1]
   if not head then
      return
   end

   head.is_block = true
   set_spaces_before(head, 1)
   for i=start+2,finish do
      node[i].trailer_start = start_node
      node[i].trailer_head = head
   end
end

function split_penalty_visitor:new()
   return setmetatable({}, { __index = split_penalty_visitor })
end
function split_penalty_visitor:visit_leaf(node)
end
function split_penalty_visitor:visit_node(node, visit)
   local n = "visit_" .. node:type()
   print(n, node:as_code())
   if self[n] then
      self[n](self, node, visit)
   else
      visit(self, node, visit)
   end
end

local function set_unbreakable_in_children(node, spaces_before)
   tree_utils.each_leaf(node, set_unbreakable, spaces_before)
end

function split_penalty_visitor:visit_function_declaration(node, visit)
   local offset = 0
   if node:is_local() then
      set_must_split(node[2]) -- `local`
      set_unbreakable(node[3]) -- `function`
      offset = 1
   else
      set_must_split(node[2]) -- `function`
   end
   visit(self, node, visit)
   set_unbreakable_in_children(node[3+offset])
end

function split_penalty_visitor:visit_statement_list(node, visit)
   node.is_block = true
   visit(self, node, visit)
end

function split_penalty_visitor:visit_parenthesized_expression(node, visit)
   node.is_block = true
   set_penalty(node[3], "unbreakable")
   set_penalty(node[#node], "unbreakable")
   visit(self, node, visit)
end

function split_penalty_visitor:visit_if_block(node, visit)
   local prev = nil
   for _, v in node:iter_rest() do
      if prev then
         if prev.value == "if" or prev.value == "elseif" then
            set_penalty(v, "unbreakable")
         else
            set_penalty(v, "strongly_connected")
         end
      end
      prev = v
   end
   visit(self, node, visit)
end

local OPERAND_PENALTIES = {
   ["or"] = "or_test",
   ["and"] = "and_test",
   ["not"] = "not_test",
   ["<"] = "comparison",
   [">"] = "comparison",
   ["<="] = "comparison",
   [">="] = "comparison",
   ["=="] = "comparison",
   ["~="] = "comparison",
   ["|"] = "or_expr",
   ["&"] = "and_expr",
   ["^"] = "xor_expr",
   [".."] = "shift_expr",
   ["+"] = "arith_expr",
   ["-"] = "arith_expr",
   ["/"] = "arith_expr",
   ["*"] = "arith_expr",
   ["#"] = "subscript",
}

function split_penalty_visitor:visit_expression(node, visit)
   visit(self, node, visit)

   for i=2,#node do
      local this_node = node[i]
      local next_node = node[i+1]
      if this_node:is_leaf()
         and (this_node.leaf_type == "Keyword" or this_node.leaf_type == "Symbol")
      then
         local penalty = OPERAND_PENALTIES[this_node.value]
         assert(penalty, this_node.value)
         increase_penalty(this_node, penalty)
      else
         increase_penalty(this_node, "term")
      end
   end
end

function split_penalty_visitor:visit_assignment_statement(node, visit)
   local offset = 0

   -- Don't ever break the list of identifiers in an assignment statement. ("local a, b, c =")
   if node:is_local() then
      set_must_split(node[2]) -- `local`
      set_unbreakable(node[3]) -- `IDENTS`
      offset = 1
   end
   if node[3+offset] then
      set_unbreakable(node[3+offset]) -- `=`
      add_trailer(node, 3+offset)
      node.is_block = true
   end
   visit(self, node, visit)
end

function split_penalty_visitor:visit_key_value_pair(node, visit)
   set_unbreakable(node[3]) -- `=`
   add_trailer(node, 3)
   visit(self, node, visit)
end

function split_penalty_visitor:visit_ident_list(node, visit)
   for i=3,#node,2 do
      set_unbreakable(node[i], 0) -- `,`
   end
   visit(self, node, visit)
end

function split_penalty_visitor:visit_expression_list(node, visit)
   for i=3,#node,2 do
      set_unbreakable(node[i], 0) -- `,`
   end
   visit(self, node, visit)
end

function split_penalty_visitor:visit_do_block(node, visit)
   self.is_block = true

   visit(self, node, visit)

   mark_block(node, 2, 4)
end

function split_penalty_visitor:visit_numeric_for_range(node, visit)
   node.is_block = true
   set_unbreakable(node[3], 1) -- `=`
   if node[5] then
      set_unbreakable(node[5], 0) -- `,`
      if node[7] then
         set_unbreakable(node[7], 0) -- `,`
      end
   end
   visit(self, node, visit)
end

function split_penalty_visitor:visit_generic_for_range(node, visit)
   node[2].is_block = true
   node[4].is_block = true
   visit(self, node, visit)
end

function split_penalty_visitor:visit_constructor_expression(node, visit)
   if node:count() == 0 then
      set_unbreakable(node[3], 0) -- `}`
   else
      for i=3,#node-1,2 do
         node[i].is_block = true -- EXPR
         if node[i+1].value == "," then
            set_unbreakable(node[i+1], 0) -- `,`
         end
      end
   end
   visit(self, node, visit)
end

function split_penalty_visitor:visit_function_parameters_and_body(node, visit)
   node[3].is_block = true
   set_unbreakable(node[2], 0) -- `(`
   visit(self, node, visit)
   if node:arguments():count() > 0 then
      set_spaces_before(node[3], 0) -- PARAMS
      node[3].is_block = true
      set_spaces_before(node[4], 0) -- ')'
   else
      set_unbreakable(node[4], 0) -- `)`
   end
   set_spaces_before(node[5], 1) -- BODY
   node[5].is_block = true
end

function split_penalty_visitor:visit_suffixed_expression(node, visit)
   add_trailer(node, 2)
   visit(self, node, visit)
end

function split_penalty_visitor:visit_member_expression(node, visit)
   node[2].spaces_required_before = 0 -- `.` / `:`
   set_penalty(node[2], "together")
   visit(self, node, visit)
   set_unbreakable(node[3], 0)
end

function split_penalty_visitor:visit_call_expression(node, visit)
   set_unbreakable(node[2], 0) -- `(`
   set_penalty(node[3], "strongly_connected")
   visit(self, node, visit)
   set_spaces_before(node[4], 0)
   if node:arguments():count() > 0 then
      set_spaces_before(node[3], 0)
   else
      set_unbreakable(node[4])
   end
end

function split_penalty_visitor:visit_return_statement(node, visit)
   add_trailer(node, 2)
   set_penalty(node[3], "strongly_connected")
   visit(self, node, visit)
end

function split_penalty_visitor:visit_statement_list(node, visit)
   if node[2] then
      node[2].spaces_required_before = 1
   end

   for i=2,#node do
      local stmt = node[i]

      if stmt.value == ";" then
         set_unbreakable(stmt, 0)
      else
         local leaf = stmt:last_leaf()
         if leaf then
            -- print("LASTLEAF",leaf,stmt)
            leaf.is_last_leaf_of_statement = true
         end
      end
   end
   visit(self, node, visit)
end

return split_penalty_visitor
