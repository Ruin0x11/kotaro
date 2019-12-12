local cst_unwrapper = {}

local visitor = require("kotaro.visitor")
local unwrapped_line = require(".kotaro.unwrapped_line")
local utils = require("kotaro.utils")
local tree_utils = require("kotaro.parser.tree_utils")

---
--- Unwrap visitor
---

local unwrap_visitor = {}

function unwrap_visitor:new()
   local data = {
      uwlines = {},
      cur_uwline = unwrapped_line(0),
      cur_depth = 0
   }
   return setmetatable(data, { __index = unwrap_visitor })
end

local function adjust_split_penalty(uwline)
end

function unwrap_visitor:start_new_line()
   if #self.cur_uwline.tokens > 0 then
      table.insert(self.uwlines, self.cur_uwline)
      adjust_split_penalty(self.cur_uwline)
   end

   self.cur_uwline = unwrapped_line(self.cur_depth)
end

function unwrap_visitor:visit_leaf(node)
   local is_whitespace = false
   if is_whitespace then
      self:start_new_line()
   elseif node.leaf_type ~= "Comment" then
      self.cur_uwline:append_node(node)
   end
end

function unwrap_visitor:visit_node(node, visit)
   local n = "visit_" .. node:type()
   if self[n] then
      self[n](self, node, visit)
   else
      visit(self, node, visit)
   end
end

local SIMPLE_EXPRS = utils.set {
   "expression",
   "return_statement",
   "ident_list",
   "suffixed_expression"
}

local function should_indent_block(node)
   -- Determine if we can keep the statements in this block on one
   -- line. We will only do this if the block contains a single
   -- statement.
   local should_indent = false

   for i = 2, #node do
      local child = node[i]
      if not child:is_leaf() then
         if child:type() == "statement_list" then
            if #child:children() > 1 then
               should_indent = true
               break
            end

            -- If there is another block inside this block, then
            -- indent the block. It gets confusing when seeing code
            -- like "if true then if true then..."
            local ch = child:first_child()
            if ch and tree_utils.is_block(ch) then
               should_indent = true
               break
            end
         elseif child:type() == "function_parameters_and_body" then
            if should_indent_block(child) then
               should_indent = true
               break
            end
         elseif not SIMPLE_EXPRS[child:type()] then
            should_indent = true
            break
         end
      end
   end

   return should_indent
end

function unwrap_visitor:has_any_tokens()
   return #self.uwlines > 0 or #self.cur_uwline.tokens > 0
end

local function visit_block(start_kw, kws_before, kws_after, do_newline)
   if do_newline == nil then
      do_newline = true
   end

   kws_before = utils.set(kws_before)
   kws_after = utils.set(kws_after)
   return function(self, node, visit)
      do_newline = do_newline and self:has_any_tokens()
      local should_indent = should_indent_block(node)

      if do_newline then
         self:start_new_line()
      end

      for i = 2, #node do
         local child = node[i]
         if i > 2
            and should_indent
            and child:is_leaf()
            and (child.value == start_kw or kws_before[child.value])
         then
            if kws_before[child.value] then
               self.cur_depth = self.cur_depth - 1
            end
            self:start_new_line()
         end

         visitor.visit(self, child)

         if should_indent
            and child:is_leaf()
            and kws_after[child.value]
         then
            self.cur_depth = self.cur_depth + 1
            self:start_new_line()
         end
      end
   end
end

function unwrap_visitor:visit_statement_list(node, visit)
   if #node == 1 then
      return
   end

   local i = 2
   repeat
      -- Split statement lists with semicolons.
      if node[i]:is_leaf() and node[i].value == ";" then
         if node[i].left then
            node[i].left.right = node[i].right
         end
         if node[i].right then
            node[i].right.left = node[i].left
         end
         node[i].left = nil
         node[i].right = nil
         table.remove(node, i)
      else
         if i > 2 then
            self:start_new_line()
         end
         visitor.visit(self, node[i])
         i = i + 1
      end
   until i > #node
end

unwrap_visitor.visit_if_block = visit_block("if", {"elseif", "else", "end"}, {"else", "then"})
unwrap_visitor.visit_do_block = visit_block("do", {"end"}, {"do"})
unwrap_visitor.visit_for_block = visit_block("for", {"end"}, {"do"})
unwrap_visitor.visit_function_parameters_and_body = visit_block(nil, {}, {")"}, false)
unwrap_visitor.visit_function_declaration = visit_block(nil, {"end"}, {})
unwrap_visitor.visit_function_expression = visit_block(nil, {"end"}, {}, false)
unwrap_visitor.visit_repeat_block = visit_block("repeat", {"until"}, {"repeat"})
unwrap_visitor.visit_while_block = visit_block("while", {"end"}, {"do"})

function unwrap_visitor:visit_constructor_expression(node)
   local i = 2
   repeat
      -- Split statement lists with semicolons.
      if node[i]:is_leaf() and node[i].value == ";" then
         if node[i].left then
            node[i].left.right = node[i].right
         end
         if node[i].right then
            node[i].right.left = node[i].left
         end
         node[i].left = nil
         node[i].right = nil
         table.remove(node, i)
      else
         visitor.visit(self, node[i])
         i = i + 1
      end
   until i > #node
end

---
--- CST unwrapper
---

function cst_unwrapper.unwrap(cst)
   local v = unwrap_visitor:new()
   visitor.visit(v, cst)

   -- flush the last line
   v:start_new_line()

   -- we may have modified the token stream due to semicolons, so
   -- update next_token/prev_token fields
   cst:changed()

   return v.uwlines
end

return cst_unwrapper
