local class = require("thirdparty.pl.class")
local Node = require("yalf.parser.nodes").node
local tree_utils = require("yalf.parser.tree_utils")

local ast_mixin = {}

function ast_mixin:is_leaf()
   return self.children == nil
end

function ast_mixin:__eq(other)
   if self.type ~= other.type then
      return false
   end

   if type(self.children) ~= type(other.children) then
      return false
   end

   if self.children then
      for i=1,#self.children do
         if self.children[i] ~= other.children[i] then
            return false
         end
      end
   end

   return true
end

function ast_mixin:__tostring()
   return self.real:__tostring()
end

function ast_mixin:expect_child(_type, index)
   local child = self.children[index]
   if child == nil then
      error("nil child")
   end
   if child.type ~= _type then
      error(string.format("Wrong child type: wanted %s, got %s (in %s)", _type, child.type, self.type))
   end
   return child
end

function ast_mixin:get_value()
   local s = self.real:get_value()
   s = string.gsub(s, "^%s*", "")
   s = string.gsub(s, "%s*$", "")
   return s
end

function ast_mixin:set_children(tbl)
   if tbl == nil then
      self.children = nil
      return
   end

   for _, v in ipairs(self.children) do
      v.parent = nil
   end

   self.children = {}

   for _, v in ipairs(tbl) do
      v.parent = self
      self.children[#self.children+1] = v
   end
end

local Program = class(ast_mixin)

function Program:_init(real, block)
   self.real = real

   -- local block = real.children[1]
   self.children = { block }
end

local Block = class(ast_mixin)

function Block:_init(real, stmts)
   self.real = real
   self.children = stmts -- real.children
end

local Assignment = class(ast_mixin)

function Assignment:_init(real, lhs, rhs)
   self.real = real
   self.children = { lhs, rhs or nil }
end

function Assignment:is_local()
   return self.real.type == "local_assignment"
end

local FunctionDeclaration = class(ast_mixin)

function FunctionDeclaration:_init(real, name, args_and_body)
   self.real = real

   self.children = { name, args_and_body }
end

function FunctionDeclaration:is_local()
   return self.real.type == "local_function_declaration"
end

function FunctionDeclaration:get_args()
   local args_and_body = self:expect_child("FunctionParametersAndBody", 2)
   return args_and_body:get_args()
end

function FunctionDeclaration:get_declarer()
   if self:is_local() then
      return nil
   end

   return self:get_name_expr():get_caller()
end

function FunctionDeclaration:set_declarer(declarer)
   if self:is_local() then
      return
   end

   self:get_name_expr():set_name_of_primary(declarer)
end

function FunctionDeclaration:set_method(is_method)
   if self:is_local() then
      return
   end
end

function FunctionDeclaration:get_name_expr()
   return self:expect_child("SuffixedExpression", 1)
end

function FunctionDeclaration:get_full_name()
   return self:get_name_expr():get_value()
end

local VariableList = class(ast_mixin)

function VariableList:_init(real, idents)
   self.real = real
   self.children = idents
end

function VariableList:as_table()
   local t = {}
   for _, v in ipairs(self.children) do
      t[#t+1] = v:get_name()
   end
   return t
end

local ValueList = class(ast_mixin)

function ValueList:_init(real, idents)
   self.real = real
   self.children = idents
end

function ValueList:as_table()
   local t = {}
   for _, v in ipairs(self.children) do
      t[#t+1] = v.type
   end
   return t
end

local KeyValuePair = class(ast_mixin)

function KeyValuePair:_init(real, key, value)
   self.real = real

   self.children = { key, value }
end

local SimpleExpression = class(ast_mixin)

function SimpleExpression:_init(real)
   self.real = real

   self.children = nil
end

local Expression = class(ast_mixin)

function Expression:_init(real, unop, exprs)
   self.real = real
   self.unop = unop or nil

   self.children = exprs
end

local function is_call(cst)
   return cst.type == "call_expression"
      or cst.type == "table_call_expression"
      or cst.type == "string_call_expression"
end

local SuffixedExpression = class(ast_mixin)

function SuffixedExpression:_init(real, exprs)
   self.real = real
   self.primary = real.children[1]
   self.trailing = {}

   self.children = exprs
end

function SuffixedExpression:get_name_of_primary()
   return self.primary.value
end

function SuffixedExpression:set_name_of_primary(name)
   self.primary.value = name
end

function SuffixedExpression:get_caller()
   local n = self.primary:get_value()
   local ind = #self.children
   local last = self.children[ind]

   if last == nil then
      -- There is no caller; primary expr indicates the function name.
      return nil
   end

   if is_call(last) then
      assert(ind > 2)
      ind = ind - 1
   end

   for i=1,ind-1 do
      n = n .. self.children[i]:get_value()
   end

   return n
end

local FunctionExpression = class(ast_mixin)

function FunctionExpression:_init(real, args_and_body)
   self.real = real

   self.children = { args_and_body }
end

local ConstructorExpression = class(ast_mixin)

function ConstructorExpression:_init(real, body)
   self.real = real

   self.children = { body }
end

local ConstructorBody = class(ast_mixin)

function ConstructorBody:_init(real, entries)
   self.real = real

   self.children = entries
end

local MemberExpression = class(ast_mixin)

function MemberExpression:_init(real)
   self.real = real
   self.member = real.children[2]

   self.children = nil
end

function MemberExpression:change_to_index()
end

local IndexExpression = class(ast_mixin)

function IndexExpression:_init(real)
   self.real = real
   self.key = real.children[2]

   self.children = nil
end

function IndexExpression:change_to_member()
end

local Arglist = class(ast_mixin)

function Arglist:_init(real, exprs)
   self.real = real

   self.children = exprs
end

function Arglist:get_nth(i)
   return self.children[i]
end

local CallExpression = class(ast_mixin)

function CallExpression:_init(real, arglist)
   self.real = real

   self.children = { arglist }
end

function CallExpression:remove_parens()
   local arglist = self.children[1]
   if arglist:get_count() ~= 1 then
      error("Argument list must have exactly one item.")
   end
   local arg = arglist:get_at(1)
   if not arg:is_simple_expression("String") then
      error("Argument must be string.")
   end
end

local StringCallExpression = class(ast_mixin)

function StringCallExpression:_init(real)
   self.real = real
   self.str = real.children[1]

   self.children = nil
end

function StringCallExpression:wrap_with_parens()
end

local TableCallExpression = class(ast_mixin)

function TableCallExpression:_init(real, tbl)
   self.real = real

   self.children = { tbl }
end

function TableCallExpression:wrap_with_parens()
end

local IfBlock = class(ast_mixin)

function IfBlock:_init(real, items)
   self.real = real

   self.children = items
end

function IfBlock:has_else()
   return #self.children % 2 == 1
end

local GenericForRange = class(ast_mixin)

function GenericForRange:_init(real, vars, generators)
   self.real = real

   self.children = {}
   self.vars = vars
   self.generators = generators

   for _, v in ipairs(vars) do
      self.children[#self.children+1] = v
   end

   for _, v in ipairs(generators) do
      self.children[#self.children+1] = v
   end
end

local NumericForRange = class(ast_mixin)

function NumericForRange:_init(real, start_expr, end_expr, step_expr)
   self.real = real

   self.children = { start_expr, end_expr, step_expr or nil }
end

local ForBlock = class(ast_mixin)

function ForBlock:_init(real, range, body)
   self.real = real

   self.children = { range, body }
end

function ForBlock:is_generic()
   return self.children[1]:is_generic()
end

function ForBlock:is_numeric()
   return self.children[1]:is_numeric()
end

local WhileBlock = class(ast_mixin)

function WhileBlock:_init(real, cond, body)
   self.real = real

   self.children = { cond, body }
end

local FunctionParametersAndBody = class(ast_mixin)

function FunctionParametersAndBody:_init(real, arglist, body)
   self.real = real

   self.children = { arglist, body }
end

function FunctionParametersAndBody:get_args()
   return self:expect_child("Arglist", 1)
end

function FunctionParametersAndBody:get_body()
   return self:expect_child("Block", 2)
end

local CallStatement = class(ast_mixin)

function CallStatement:_init(real, suff)
   self.real = real

   self.children = { suff }
end

function CallStatement:get_trailing()
   return #self.children % 2 == 1
end

local ReturnStatement = class(ast_mixin)

function ReturnStatement:_init(real, value_list)
   self.real = real

   self.children = { value_list }
end

function ReturnStatement:get_rhs()
   return self.children[1]
end

local AstNodes = {
   Program = Program,
   Block = Block,
   Assignment = Assignment,
   KeyValuePair = KeyValuePair,
   VariableList = VariableList,
   ValueList = ValueList,
   SuffixedExpression = SuffixedExpression,
   Expression = Expression,
   SimpleExpression = SimpleExpression,
   FunctionExpression = FunctionExpression,
   IndexExpression = IndexExpression,
   MemberExpression = MemberExpression,
   FunctionParametersAndBody = FunctionParametersAndBody,
   ConstructorExpression = ConstructorExpression,
   ConstructorBody = ConstructorBody,
   FunctionDeclaration = FunctionDeclaration,
   IfBlock = IfBlock,
   WhileBlock = WhileBlock,
   GenericForRange = GenericForRange,
   NumericForRange = NumericForRange,
   ForBlock = ForBlock,
   Arglist = Arglist,
   CallStatement = CallStatement,
   CallExpression = CallExpression,
   StringCallExpression = StringCallExpression,
   TableCallExpression = TableCallExpression,
   ReturnStatement = ReturnStatement
}

local function mknode(name, real, ...)
   local n = AstNodes[name]
   assert(n, name)
   local o = n(real, ...)
   o.type = name
   return o
end

-- Visits a CST and creates an AST backed by it.
local ast_maker = {}

function ast_maker:new()
   local o = setmetatable({}, { __index = ast_maker })
   o.ast = nil
   return o
end

function ast_maker:visit_program(node)
   local block = self:expect("block", node.children[1])

   return mknode("Program", node, block)
end

function ast_maker:visit_assignment_statement(node)
   local lhs = self:visit(node.children[1])
   local rhs = self:visit(node.children[3])

   return mknode("Assignment", node, lhs, rhs)
end

function ast_maker:visit_local_assignment(node)
   local stmt = node.children[2]
   assert(stmt.type == "assignment_statement")

   local lhs = self:visit(stmt.children[1])

   -- local assignment can omit the value list.
   local rhs
   if stmt.children[3] then
      rhs = self:visit(stmt.children[3])
   end

   return mknode("Assignment", node, lhs, rhs)
end

function ast_maker:visit_variable_list(node)
   local idents = {}
   for i, v in ipairs(node.children) do
      if i % 2 == 1 and v.type == "suffixed_expression" then
         idents[#idents+1] = self:visit(v)
      end
   end

   return mknode("VariableList", node, idents)
end

function ast_maker:visit_value_list(node)
   local exprs = {}
   for i, v in ipairs(node.children) do
      if i % 2 == 1 and v.type == "expression" then
         exprs[#exprs+1] = self:visit(v)
      end
   end

   return mknode("ValueList", node, exprs)
end

local function is_unop(cst)
   return cst == "-" or cst == "not" or cst == "#"
end

function ast_maker:visit_expression(node)

   local first = node.children[1]
   local exprs = {}
   local unop, expr

   if first:is_leaf() then
      if is_unop(first) then
         unop = first
         expr = node.children[2]
      else
         -- simple expression
         expr = mknode("SimpleExpression", first)
      end
   else
      expr = self:visit(first)
   end

   exprs = { expr }

   -- BUG: more than 1 expression

   assert(expr ~= nil)

   return mknode("Expression", node, unop, exprs)
end

function ast_maker:visit_suffixed_expression(node)
   local exprs = {}
   for i=2,#node.children do
      local child = node.children[i]
      exprs[#exprs+1] = self:visit(child)
   end
   return mknode("SuffixedExpression", node, exprs)
end

function ast_maker:visit_numeric_for_range(node)
   local start_expr = self:expect("expression", node.children[3])
   local end_expr = self:expect("expression", node.children[5])

   local step_expr
   if node.children[7] then
      step_expr = self:expect("expression", node.children[7])
   end

   return mknode("NumericForRange", node, start_expr, end_expr, step_expr)
end

function ast_maker:visit_generic_for_range(node)
   local vars = node.children[1]
   local generators = node.children[2]

   local var_nodes = {}
   local generator_nodes = {}

   for _, v in ipairs(vars) do
      var_nodes[#var_nodes+1] = self:visit(v)
   end

   for _, v in ipairs(generators) do
      generator_nodes[#generator_nodes+1] = self:visit(v)
   end

   return mknode("GenericForRange", node, var_nodes, generator_nodes)
end

function ast_maker:visit_for_block(node)
   local for_range = self:visit(node.children[2])
   local block = self:expect("block", node.children[4])

   return mknode("ForBlock", node, for_range, block)
end

function ast_maker:visit_while_block(node)
   local expr = self:expect("expression", node.children[2])
   local block = self:expect("block", node.children[4])

   return mknode("WhileBlock", node, expr, block)
end

function ast_maker:visit_if_block(node)
   local items = {}
   for i=1,#node.children,2 do
      local kw = node.children[i]
      local cst = node.children[i+1]

      assert(kw.type == "Keyword")

      if kw.value == "if"
      or kw.value == "elseif" then
         items[#items+1] = self:visit(cst)
      elseif kw.value == "then" then
         items[#items+1] = self:visit(cst)
      elseif kw.value == "else" then
         items[#items+1] = self:visit(cst)
      elseif kw.value == "end" then
         break
      else
         error("unknown if keyword " .. tostring(kw.value))
      end
   end
   return mknode("IfBlock", node, items)
end

function ast_maker:visit_function_parameters_and_body(node)
   local arglist = self:expect("arglist", node.children[2])
   local body = self:expect("block", node.children[4])

   return mknode("FunctionParametersAndBody", node, arglist, body)
end

function ast_maker:visit_function_declaration(node)
   local name = self:expect("suffixed_expression", node.children[2])
   local args_and_body = self:expect("function_parameters_and_body", node.children[3])

   return mknode("FunctionDeclaration", node, name, args_and_body)
end

function ast_maker:visit_local_function_declaration(node)
   local block = self:expect("function_declaration", node.children[2])
   local name = block.children[1]
   local args_and_body = block.children[2]

   return mknode("FunctionDeclaration", node, name, args_and_body)
end

function ast_maker:visit_arglist(node)
   local exprs = {}
   for i=1,#node.children,2 do
      local expr = node.children[i]
      if expr:is_leaf() then
         exprs[#exprs+1] = mknode("SimpleExpression", expr)
      else
         exprs[#exprs+1] = self:visit(expr)
      end
   end

   return mknode("Arglist", node, exprs)
end

function ast_maker:visit_key_value_pair(node)
   local key = node.children[1]
   if key:is_leaf() then
      key = mknode("SimpleExpression", key)
   else
      key = self:expect("constructor_key", node)
   end

   local value = self:expect("expression", node.children[3])

   return mknode("KeyValuePair", node, key, value)
end

function ast_maker:visit_constructor_body(node)
   local items = {}

   -- skip commas
   for i=1,#node.children,2 do
      local child = node.children[i]
      items[#items+1] = self:visit(child)
   end

   return mknode("ConstructorBody", node, items)
end

function ast_maker:visit_function_expression(node)
   local args_and_body = self:expect("function_parameters_and_body", node.children[2])

   return mknode("FunctionExpression", node, args_and_body)
end

function ast_maker:visit_constructor_expression(node)
   local body = self:expect("constructor_body", node.children[2])

   return mknode("ConstructorExpression", node, body)
end

function ast_maker:visit_index_expression(node)
   local expr = self:expect("expression", node.children[2])

   return mknode("IndexExpression", node, expr)
end

function ast_maker:visit_member_expression(node)
   return mknode("MemberExpression", node)
end

function ast_maker:visit_string_call_expression(node)
   return mknode("StringCallExpression", node)
end

function ast_maker:visit_call_expression(node)
   local arglist = self:expect("arglist", node.children[2])

   return mknode("CallExpression", node, arglist)
end

function ast_maker:visit_call_statement(node)
   local suff = self:expect("suffixed_expression", node.children[1])

   return mknode("CallStatement", node, suff)
end

function ast_maker:visit_return_statement(node)
   local value_list = self:expect("value_list", node.children[2])

   return mknode("ReturnStatement", node, value_list)
end

function ast_maker:visit_block(node)
   local stmts = {}
   for _, child in ipairs(node.children) do
      stmts[#stmts + 1] = self:visit(child)
   end
   return mknode("Block", node, stmts)
end

function ast_maker:expect(_type, child)
   if child.type ~= _type then
      error("wanted type " .. _type .. ", got " .. child.type)
   end

   return self:visit(child)
end

function ast_maker:visit(node)
   assert(not node:is_leaf(), tostring(node.type) .. " - " .. tostring(node.value))

   local f = self["visit_" .. node.type]
   if not f then
      error("unknown node " .. node.type)
   end

   return f(self, node)
end

return ast_maker
