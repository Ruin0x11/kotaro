local class = require("thirdparty.pl.class")
local nodes = require("yalf.parser.nodes")
local Node = nodes.node
local Leaf = nodes.leaf
local lexer = require("yalf.parser.lexer")
local utils = require("yalf.utils")

local NodeTypes = {}

function NodeTypes.program(tree, l_eof)
   return Node("program", {tree, l_eof})
end

function NodeTypes.if_block(nodes)
   return Node("if_block", nodes)
end

function NodeTypes.while_block(l_while, cond, l_do, body, l_end)
   return Node("while_block", {l_while, cond, l_do, body, l_end})
end

function NodeTypes.do_block(l_do, body, l_end)
   return Node("do_block", {l_do, body, l_end})
end

function NodeTypes.numeric_for_range(var_name, l_equals, start_expr, l_comma_a, end_expr, l_comma_b, step_expr)
   return Node("numeric_for_range", {var_name, l_equals, start_expr, l_comma_a, end_expr, l_comma_b or nil, step_expr or nil})
end

function NodeTypes.generic_for_range(variables, l_in, generators)
   return Node("generic_for_range", {variables, l_in, generators})
end

function NodeTypes.generic_for_variables(vars)
   return Node("generic_for_variables", vars)
end

function NodeTypes.generic_for_generators(generators)
   return Node("generic_for_generators", generators)
end

function NodeTypes.for_block(l_for, for_range, l_do, block, l_end)
   return Node("for_block", {l_for, for_range, l_do, block, l_end})
end

function NodeTypes.repeat_statement(l_repeat, block, l_until, cond)
   return Node("repeat_statement", {l_repeat, block, l_until, cond})
end

function NodeTypes.function_block(l_function, name, block, l_end)
   return Node("function_block", {l_function, name, block, l_end})
end

function NodeTypes.local_function_declaration(l_local, block)
   return Node("local_function_declaration", {l_local, block})
end

function NodeTypes.local_assignment(l_local, assign)
   return Node("local_assignment", {l_local, assign})
end

function NodeTypes.block(children)
   return Node("block", children)
end

function NodeTypes.label(label)
   return Node("label", {label})
end

function NodeTypes.return_statement(l_return, exprs)
   return Node("return_statement", {l_return, exprs})
end

function NodeTypes.break_statement(l_break)
   return Node("break_statement", {l_break})
end

function NodeTypes.goto_statement(l_goto, label)
   return Node("goto_statement", {l_goto, label})
end

function NodeTypes.call_statement(expr)
   return Node("call_statement", {expr})
end

function NodeTypes.lhs_list(lhs)
   return Node("lhs_list", lhs)
end

function NodeTypes.rhs_list(rhs)
   return Node("rhs_list", rhs)
end

function NodeTypes.assignment_statement(lhs, l_equals, rhs)
   return Node("assignment_statement", {lhs, l_equals, rhs})
end

function NodeTypes.parenthesized_expression(l_lparen, expr, l_rparen)
   return Node("parenthesized_expression", {l_lparen, expr, l_rparen})
end

function NodeTypes.statement_with_semicolon(stmt, semicolon)
   return Node("statement_with_semicolon", {stmt, semicolon})
end

function NodeTypes.expression(ops_and_numbers)
   return Node("expression", ops_and_numbers)
end

function NodeTypes.constructor_key(l_lbracket, entries, l_rbracket)
   return Node("constructor_key", {l_lbracket, entries, l_rbracket})
end

function NodeTypes.constructor_value(value)
   return Node("constructor_value", {value})
end

function NodeTypes.key_value_pair(key, l_equals, value)
   return Node("key_value_pair", {key, l_equals, value})
end

function NodeTypes.constructor_body(entries)
   return Node("constructor_body", entries)
end

function NodeTypes.constructor_expression(l_lbrace, body, l_rbrace)
   return Node("constructor_expression", {l_lbrace, body, l_rbrace})
end

function NodeTypes.variable_expression(expr)
   return Node("variable_expression", {expr})
end

function NodeTypes.primary_expression(expr)
   return Node("primary_expression", {expr})
end

function NodeTypes.member_expression(l_dot_or_colon, id)
   return Node("member_expression", {l_dot_or_colon, id})
end

function NodeTypes.index_expression(l_lbracket, expr, l_rbracket)
   return Node("index_expression", {l_lbracket, expr, l_rbracket})
end

function NodeTypes.call_expression(l_lparen, arglist, l_rparen)
   return Node("call_expression", {l_lparen, arglist, l_rparen})
end

function NodeTypes.table_call_expression(expr)
   return Node("table_call_expression", {expr})
end

function NodeTypes.string_call_expression(l_str)
   return Node("string_call_expression", {l_str})
end

function NodeTypes.suffixed_expression(nodes)
   return Node("suffixed_expression", nodes)
end

function NodeTypes.arglist(args)
   return Node("arglist", args)
end

function NodeTypes.function_parameters_and_body(params, body)
   return Node("function_parameters_and_body", {params, body})
end

function NodeTypes.function_parameters(l_lparen, arglist, l_rparen)
   return Node("function_parameters", {l_lparen, arglist, l_rparen})
end

function NodeTypes.function_expression(l_function, body, l_end)
   return Node("function_parameters", {l_function, body, l_end})
end

-- Takes tokenized source and converts it to a Concrete Syntax Tree
-- (CST), which preserves whitespace and comments. The intent is to be
-- able to serialize the CST into a string containing the exact source
-- passed on.
local cst_parser = class()

function cst_parser:_init(src)
   self.src = src
   self.lexer = lexer(src)
end

function cst_parser:generate_error(msg)
   local t = self.lexer:peekToken()
   local err = string.format(">> :%s:%s: %s\n", t.line, t.column, msg)
   --find the line
   local lineNum = 0
   if type(self.src) == 'string' then
      for line in self.src:gmatch("[^\n]*\n?") do
         if line:sub(-1,-1) == '\n' then line = line:sub(1,-2) end
         lineNum = lineNum+1
         if lineNum == t.line then
            err = err..">> `"..line:gsub('\t','    ').."`\n"
            for i = 1, t.column do
               local c = line:sub(i,i)
               if c == '\t' then
                  err = err..'    '
               else
                  err = err..' '
               end
            end
            err = err.."   ^^^^"
            break
         end
      end
   end
   return err
end

--
--
-- Expressions
--
--

function cst_parser:parse_function_args_and_body()
   local l_lparen = self.lexer:consumeSymbol("(")
   if not l_lparen then
      return false, self:generate_error("`(` expected")
   end

   local args = {}
   local l_rparen = self.lexer:consumeSymbol(")")

   while not l_rparen do
      if self.lexer:tokenIs("Ident") then
         args[#args+1] = self.lexer:consumeToken()
         local l_comma = self.lexer:consumeSymbol(",")
         if not l_comma then
            l_rparen = self.lexer:consumeSymbol(")")
            if not l_rparen then
               return false, self:generate_error("`)` expected")
            end
         end
      else
         local l_varargs = self.lexer:consumeSymbol("...")
         if l_varargs then
            args[#args+1] = l_varargs
            l_rparen = self.lexer:consumeSymbol(")")
            if not l_rparen then
               return false, self:generate_error("`...` must be the last argument of a function")
            end
         else
            return false, self:generate_error("argument name or `...` expected")
         end
      end
   end

   local st, body = self:parse_block()
   if not st then return st, body end

   local arglist = NodeTypes.arglist(args)
   local func_params = NodeTypes.function_parameters(l_lparen, arglist, l_rparen)

   -- TODO: funcdef --> (def -> name -> parameters -> suite)
   return true, NodeTypes.function_parameters_and_body(func_params, body)
end

function cst_parser:parse_parenthesized_expression()
   local l_lparen = self.lexer:consumeSymbol("(")
   assert(l_lparen)

   local st, expr = self:parse_expression()
   if not st then return st, expr end

   local l_rparen = self.lexer:consumeSymbol(")")

   if not l_rparen then return false, self:generate_error("`)` expected") end

   return true, NodeTypes.parenthesized_expression(l_lparen, expr, l_rparen)
end

function cst_parser:parse_primary_expression()
   local st, expr

   if self.lexer:tokenIsSymbol("(") then
      st, expr = self:parse_parenthesized_expression()
      if not st then return st, expr end
   elseif self.lexer:tokenIs("Ident") then
      local id = self.lexer:consumeToken()

      assert(id.type == "Ident")
      expr = NodeTypes.variable_expression(id)
   end

   return true, NodeTypes.primary_expression(expr)
end

function cst_parser:parse_suffixed_expression(only_dots)
   local st, primary = self:parse_primary_expression()
   if not st then return st, primary end

   local expr
   local exprs = { primary }

   while true do
      if self.lexer:tokenIsSymbol(".") or self.lexer:tokenIsSymbol(":") then
         local l_dot_or_colon = self.lexer:consumeToken()

         if not self.lexer:tokenIs("Ident") then
            return false, self:generate_error("<Ident> expected.")
         end

         local id = self.lexer:consumeToken()

         expr = NodeTypes.member_expression(l_dot_or_colon, id)
      elseif not only_dots and self.lexer:tokenIsSymbol("[") then
         local l_lbracket = self.lexer:consumeToken()
         local st, ex = self:parse_expression()
         if not st then return st, ex end
         local l_rbracket = self.lexer:consumeSymbol("]")
         if not l_rbracket then
            return false, self:generate_error("`]` expected")
         end

         expr = NodeTypes.index_expression(l_lbracket, ex, l_rbracket)
      elseif not only_dots and self.lexer:tokenIsSymbol("(") then
         local args = {}
         local l_lparen = self.lexer:consumeToken()
         local l_rparen
         while not l_rparen do
            local st, ex = self:parse_expression()
            if not st then return st, ex end
            args[#args+1] = ex
            local l_comma = self.lexer:consumeSymbol(",")
            if l_comma then
               args[#args+1] = l_comma
            else
               l_rparen = self.lexer:consumeSymbol(")")
               if not l_rparen then
                  return false, self:generate_error("`)` expected")
               end
            end
         end

         local arglist = NodeTypes.arglist(args)

         expr = NodeTypes.call_expression(l_lparen, arglist, l_rparen)
      elseif not only_dots and self.lexer:tokenIs("String") then
         local l_str = self.lexer:consumeToken()
         expr = NodeTypes.string_call_expression(l_str)
      elseif not only_dots and self.lexer:tokenIsSymbol("{") then
         local st, ex = self:parse_simple_expression()
         if not st then return st, ex end

         -- FIXME

         expr = NodeTypes.table_call_expression(ex)
      else
         break
      end

      exprs[#exprs+1] = expr
   end

   return true, NodeTypes.suffixed_expression(exprs)
end

function cst_parser:parse_constructor_key()
   -- literal key like [1] or ["some.key"]
   local l_lbracket = self.lexer:consumeSymbol("[")
   assert(l_lbracket)

   local st, key = self:parse_expression()
   if not st then return st, key end

   local l_rbracket = self.lexer:consumeSymbol("]")
   if not l_rbracket then
      return false, self:generate_error("`]` expected")
   end

   local l_equals = self.lexer:consumeSymbol("=")
   if not l_equals then
      return false, self:generate_error("`=` expected")
   end

   local st, val = self:parse_expression()
   if not st then return st, val end

   local cons_key = NodeTypes.constructor_key(l_lbracket, key, l_rbracket)
   local cons_val = NodeTypes.constructor_value(val)

   return true, NodeTypes.key_value_pair(cons_key, l_equals, cons_val)
end

function cst_parser:parse_value_or_key()
   local lookahead = self.lexer:peekToken(1)
   if lookahead.type == "Symbol" and lookahead.value == "=" then
      local key = self.lexer:consumeToken()

      local l_equals = self.lexer:consumeSymbol("=")
      if not l_equals then
         return false, self:generate_error("value expression expected")
      end

      local st, value = self:parse_expression()
      if not st then return st, value end

      return true, NodeTypes.key_value_pair(key, l_equals, value)
   end

   local st, value = self:parse_expression()
   if not st then return st, value end

   return true, NodeTypes.constructor_value(value)
end

function cst_parser:parse_constructor_expression()
   local l_lbracket = self.lexer:consumeSymbol("{")
   assert(l_lbracket)

   local l_rbracket
   local entries = {}

   while true do
      if self.lexer:tokenIsSymbol("[") then
         local st, key = self:parse_constructor_key()
         if not st then return st, key end
         entries[#entries+1] = key
      elseif self.lexer:tokenIs("Ident") then
         local st, value_or_key = self:parse_value_or_key()
         if not st then return st, value_or_key end
         entries[#entries + 1] = value_or_key
      else
         l_rbracket = self.lexer:consumeSymbol("}")
         if l_rbracket then
            break
         else
            local st, value = self:parse_expression()
            if not st then return false, self:generate_error("value expected") end

            entries[#entries+1] = value
         end
      end

      local ok = false
      local l_semicolon = self.lexer:consumeSymbol(";")
      if l_semicolon then
         entries[#entries+1] = l_semicolon
         ok = true
      else
         local l_comma = self.lexer:consumeSymbol(",")
         if l_comma then
            entries[#entries+1] = l_comma
            ok = true
         end
      end

      if not ok then
         l_rbracket = self.lexer:consumeSymbol("}")
         if l_rbracket then
            break
         end
      end

      if not ok then
         return false, self:generate_error("`}` or table entry expected")
      end
   end

   local body = NodeTypes.constructor_body(entries)

   return true, NodeTypes.constructor_expression(l_lbracket, body, l_rbracket)
end

function cst_parser:parse_function_expression()
   local l_function = self.lexer:consumeKeyword("function")
   assert(l_function)

   local st, body = self:parse_function_args_and_body()
   if not st then return st, body end


   local l_end = self.lexer:consumeKeyword("end")
   if not l_end then
      return false, self:generate_error("`end` expected")
   end

   return true, NodeTypes.function_expression(l_function, body, l_end)
end

function cst_parser:parse_simple_expression()
   if self.lexer:tokenIs("Number") then
      return true, Leaf("number", self.lexer:consumeToken())
   elseif self.lexer:tokenIs("String") then
      return true, Leaf("string", self.lexer:consumeToken())
   elseif self.lexer:tokenIsKeyword("nil") then
      return true, Leaf("nil", self.lexer:consumeToken())
   elseif self.lexer:tokenIsKeyword("false") or self.lexer:tokenIsKeyword("true") then
      return true, Leaf("boolean", self.lexer:consumeToken())
   elseif self.lexer:tokenIsSymbol("...") then
      return true, Leaf("varargs", self.lexer:consumeToken())
   elseif self.lexer:tokenIsSymbol("{") then
      return self:parse_constructor_expression()
   elseif self.lexer:tokenIsKeyword("function") then
      return self:parse_function_expression()
   end

   return self:parse_suffixed_expression()
end

local unops = utils.set{'-', 'not', '#'}
local priority = {
   ['+'] = {6,6};
   ['-'] = {6,6};
   ['%'] = {7,7};
   ['/'] = {7,7};
   ['*'] = {7,7};
   ['^'] = {10,9};
   ['..'] = {5,4};
   ['=='] = {3,3};
   ['<'] = {3,3};
   ['<='] = {3,3};
   ['~='] = {3,3};
   ['>'] = {3,3};
   ['>='] = {3,3};
   ['and'] = {2,2};
   ['or'] = {1,1};
}

function cst_parser:parse_expression()
   local st, exp

   local ops = {}

   if unops[self.lexer:peekToken().value] then
      local op = self.lexer:consumeToken()
      ops[#ops+1] = op

      st, exp = self:parse_expression()
      if not st then return st, exp end

      ops[#ops+1] = exp
   else
      st, exp = self:parse_simple_expression()
      if not st then return st, exp end
      ops[#ops+1] = exp
   end

   while priority[self.lexer:peekToken().value] do
      local op = self.lexer:consumeToken()

      ops[#ops+1] = op

      st, exp = self:parse_simple_expression()
      if not st then return st, exp end

      ops[#ops+1] = exp
   end

   return true, NodeTypes.expression(ops)
end

--
--
-- Blocks
--
--

function cst_parser:parse_if_block()
   assert(self.lexer:tokenIsKeyword("if"))
   local l_if = self.lexer:consumeToken()

   local nodes = { l_if }

   local l_elseif
   repeat
      local st, cond = self:parse_expression()
      if not st then return false, cond end

      nodes[#nodes+1] = cond

      local l_then = self.lexer:consumeKeyword("then")
      if not l_then then
         return false, self:generate_error("`then` expected.")
      end

      nodes[#nodes+1] = l_then

      local st, body = self:parse_block()
      if not st then return false, body end

      nodes[#nodes+1] = body

      l_elseif = self.lexer:consumeKeyword("elseif")
      if l_elseif then
         nodes[#nodes+1] = l_elseif
      end
   until not l_elseif

   local l_else = self.lexer:consumeKeyword("else")
   if l_else then
      nodes[#nodes+1] = l_else

      local st, body = self:parse_block()
      if not st then return false, body end

      nodes[#nodes+1] = body
   end

   local l_end = self.lexer:consumeKeyword("end")
   if not l_end then
      return false, self:generate_error("`end` expected.")
   end

   nodes[#nodes+1] = l_end

   return true, NodeTypes.if_block(nodes)
end

function cst_parser:parse_while_block()
   local l_while = self.lexer:consumeKeyword("while")
   assert(l_while)

   local st, cond = self:parse_expression()
   if not st then return false, cond end

   local l_do = self.lexer:consumeKeyword("do")
   if not l_do then
      return false, self:generate_error("`do` expected.")
   end

   local st, body = self:parse_block()
   if not st then return false, body end

   local l_end = self.lexer:consumeKeyword("end")
   if not l_end then
      return false, self:generate_error("`end` expected.")
   end

   return true, NodeTypes.while_block(l_while, cond, l_do, body, l_end)
end

function cst_parser:parse_do_block()
   local l_do = self.lexer:consumeKeyword("do")
   assert(l_do)

   local st, body = self:parse_block()
   if not st then return false, body end

   local l_end = self.lexer:consumeKeyword("end")
   if not l_end then
      return false, self:generate_error("`end` expected.")
   end

   return true, NodeTypes.do_block(l_do, body, l_end)
end

function cst_parser:parse_numeric_for_range(var_name)
   local l_equals = self.lexer:consumeSymbol("=")
   assert(l_equals)

   local st, start_expr = self:parse_expression()
   if not st then return false, start_expr end

   local l_comma_a = self.lexer:consumeSymbol(",")
   if not l_comma_a then
      return false, self:generate_error("`,` expected.")
   end

   local st, end_expr = self:parse_expression()
   if not st then return false, end_expr end

   local step_expr
   local l_comma_b = self.lexer:consumeSymbol(",")
   if l_comma_b then
      st, step_expr = self:parse_expression()
      if not st then return false, step_expr end
   end

   return true, NodeTypes.numeric_for_range(var_name, l_equals, start_expr, l_comma_a, end_expr, l_comma_b, step_expr)
end

function cst_parser:parse_generic_for_range(var_name)
   local vars = { var_name }

   local l_comma = self.lexer:consumeSymbol(",")
   while l_comma do
      vars[#vars+1] = l_comma
      if not self.lexer:tokenIs("Ident") then
         return false, self:generate_error("for variable expected.")
      end

      vars[#vars+1] = self.lexer:consumeToken()

      l_comma = self.lexer:consumeSymbol(",")
   end

   local l_in = self.lexer:consumeKeyword("in")
   if not l_in then
      return false, self:generate_error("`in` expected.")
   end

   local generators = {}
   local st, first_generator = self:parse_expression()
   if not st then return false, first_generator end
   generators[1] = first_generator

   l_comma = self.lexer:consumeSymbol(",")
   while l_comma do
      generators[#generators+1] = l_comma

      local st, gen = self:parse_expression()
      if not st then return st, gen end

      generators[#generators+1] = gen

      l_comma = self.lexer:consumeSymbol(",")
   end

   local vars_node = NodeTypes.generic_for_variables(vars)
   local generators_node = NodeTypes.generic_for_generators(generators)

   return true, NodeTypes.generic_for_range(vars_node, l_in, generators_node)
end

function cst_parser:parse_for_block()
   local l_for = self.lexer:consumeKeyword("for")
   assert(l_for)

   if not self.lexer:tokenIs("Ident") then
      return false, self:generate_error("<ident> expected.")
   end

   local var_name = self.lexer:consumeToken()

   local st, for_range
   if self.lexer:tokenIsSymbol("=") then
      st, for_range = self:parse_numeric_for_range(var_name)
   else
      st, for_range = self:parse_generic_for_range(var_name)
   end

   if not st then return st, for_range end

   local l_do = self.lexer:consumeKeyword("do")
   if not l_do then
      return false, self:generate_error("`do` expected.")
   end

   local st, block = self:parse_block()
   if not st then return st, block end

   local l_end = self.lexer:consumeKeyword("end")
   if not l_end then
      return false, self:generate_error("`end` expected.")
   end

   return true, NodeTypes.for_block(l_for, for_range, l_do, block, l_end)
end

function cst_parser:parse_repeat_block()
   local l_repeat = self.lexer:consumeKeyword("repeat")
   assert(l_repeat)

   local st, block = self:parse_block()
   if not st then return st, block end

   local l_until = self.lexer:consumeKeyword("until")
   if not l_until then
      return false, self:generate_error("`until` expected.")
   end

   local st, cond = self:parse_expression()
   if not st then return false, cond end

   return true, NodeTypes.repeat_statement(l_repeat, block, l_until, cond)
end

function cst_parser:parse_function_block()
   local l_function = self.lexer:consumeKeyword("function")
   assert(l_function)

   if not self.lexer:tokenIs("Ident") then
      return false, self:generate_error("Function name expected")
   end

   local st, name = self:parse_suffixed_expression(true)
   if not st then return false, name end

   local st, func = self:parse_function_args_and_body()
   if not st then return false, func end

   local l_end = self.lexer:consumeKeyword("end")
   if not l_end then
      return false, self:generate_error("`end` expected")
   end

   return true, NodeTypes.function_block(l_function, name, func, l_end)
end

--
--
-- Statements
--
--

function cst_parser:parse_local()
   local l_local = self.lexer:consumeKeyword("local")
   assert(l_local)

   if self.lexer:tokenIs("Ident") then
      local st, suff = self:parse_suffixed_expression()
      if not st then return st, suff end

      local st, assign = self:parse_assignment(suff)
      if not st then return st, assign end

      return true, NodeTypes.local_assignment(l_local, assign)
   elseif self.lexer:tokenIsKeyword("function") then
      local st, func = self:parse_function_block()
      if not st then return st, func end
      return true, NodeTypes.local_function_declaration(l_local, func)
   end

   return false, self:generate_error("local var or function def expected")
end

function cst_parser:parse_label()
   local l_colons_a = self.lexer:consumeSymbol("::")
   assert(l_colons_a)

   if not self.lexer:tokenIs("Ident") then
      return false, self:generate_error("Label name expected")
   end

   local label = self:consumeToken()

   local l_colons_b = self.lexer:consumeSymbol("::")
   if not l_colons_b then
      return false, self:generate_error("`::` expected")
   end

   return true, NodeTypes.label(l_colons_a, label, l_colons_b)
end

function cst_parser:parse_return()
   local l_return = self.lexer:consumeKeyword("return")
   assert(l_return)

   local exprs = {}
   if not self.lexer:tokenIsKeyword("end") then
      local st, first_expr = self:parse_expression()
      if st then
         exprs[1] = first_expr
         while self.lexer:consumeSymbol(",") do
            local st, ex = self:parse_expression()
            if not st then return false, ex end
            exprs[#exprs+1] = ex
         end
      end
   end

   local rhs_list = NodeTypes.rhs_list(exprs)

   return true, NodeTypes.return_statement(l_return, rhs_list)
end

function cst_parser:parse_break()
   local l_break = self.lexer:consumeKeyword("break")
   assert(l_break)

   return true, NodeTypes.break_statement(l_break)
end

function cst_parser:parse_goto()
   local l_goto = self.lexer:consumeKeyword("l_goto")
   assert(l_goto)

   if not self.lexer:tokenIs("Ident") then
      return false, self:generate_error("Label expected")
   end

   local label = self:consumeToken()

   return true, NodeTypes.goto_statement(l_goto, label)
end

function cst_parser:parse_assignment(suffixed)
   if suffixed.type == "parenthesized_expression" then
      return false, self:generate_error("Cannot assign to a parenthesized expression, is not an lvalue")
   end

   local lhs = { suffixed }
   local l_comma = self.lexer:consumeSymbol(",")
   while l_comma do
      lhs[#lhs+1] = l_comma
      local st, lhs_part = self:parse_suffixed_expression()
      if not st then return st, lhs_part end

      lhs[#lhs+1] = lhs_part

      l_comma = self.lexer:consumeSymbol(",")
   end

   local l_equals = self.lexer:consumeSymbol("=")
   if not l_equals then
      return false, self:generate_error("`=` expected")
   end

   local rhs = {}
   local st, first_rhs = self:parse_expression()
   if not st then return st, first_rhs end
   rhs[1] = first_rhs

   l_comma = self.lexer:consumeSymbol(",")
   while l_comma do
      rhs[#rhs+1] = l_comma

      local st, rhs_part = self:parse_expression()
      if not st then return false, rhs_part end

      rhs[#rhs+1] = rhs_part
   end

   local lhs_node = NodeTypes.lhs_list(lhs)
   local rhs_node = NodeTypes.rhs_list(rhs)

   return true, NodeTypes.assignment_statement(lhs_node, l_equals, rhs_node)
end

function cst_parser:parse_assignment_or_call()
   local st, suffixed = self:parse_suffixed_expression()
   if not st then return st, suffixed end

   local stmt
   if self.lexer:tokenIsSymbol(",") or self.lexer:tokenIsSymbol("=") then
      st, stmt = self:parse_assignment(suffixed)
      if not st then return st, stmt end
   else
      local inner = suffixed.children[#suffixed.children]
      assert(inner)
      if inner.type == "call_expression"
         or inner.type == "table_call_expression"
         or inner.type == "string_call_expression"
      then
         stmt = NodeTypes.call_statement(suffixed)
      else
         return false, self:generate_error("assignment statement expected")
      end
   end

   return true, stmt
end

function cst_parser:parse_statement()
   local st, stmt

   local lookahead = self.lexer:peekToken()

   if lookahead.type == "Keyword" then
      if lookahead.value == "if" then
         st, stmt = self:parse_if_block()
      elseif lookahead.value == "while" then
         st, stmt = self:parse_while_block()
      elseif lookahead.value == "do" then
         st, stmt = self:parse_do_block()
      elseif lookahead.value == "for" then
         st, stmt = self:parse_for_block()
      elseif lookahead.value == "repeat" then
         st, stmt = self:parse_repeat_block()
      elseif lookahead.value == "function" then
         st, stmt = self:parse_function_block()
      elseif lookahead.value == "local" then
         st, stmt = self:parse_local()
      elseif lookahead.value == "::" then
         st, stmt = self:parse_label()
      elseif lookahead.value == "return" then
         st, stmt = self:parse_return()
      elseif lookahead.value == "break" then
         st, stmt = self:parse_break()
      elseif lookahead.value == "goto" then
         st, stmt = self:parse_goto()
      else
         st, stmt = self:parse_assignment_or_call()
      end
   else
      st, stmt = self:parse_assignment_or_call()
   end

   if self.lexer:tokenIsSymbol(";") then
      local l_semicolon = self:consumeToken()
      stmt = NodeTypes.statement_with_semicolon(stmt, l_semicolon)
   end

   return st, stmt
end

local block_end_kwords = utils.set{"end", "else", "elseif", "until"}

function cst_parser:parse_block()
   local statements = {}

   while not (block_end_kwords[self.lexer:peekToken().value] or self.lexer:isEof()) do
      local st, statement = self:parse_statement()
      if not st then return false, statement end
      assert(statement)
      statements[#statements+1] = statement
   end

   return true, NodeTypes.block(statements)
end

function cst_parser:parse()
   local st, tree = self:parse_block()
   if not st then
      return false, tree
   end

   assert(self.lexer:isEof())
   local l_eof = self.lexer:peekToken()

   return true, NodeTypes.program(tree, l_eof)
end

return cst_parser
