local visitors = require("yalf.visitor.visitors")
local visitor = visitors.visitor
local tree_utils = require("yalf.parser.tree_utils")
local utils = require("yalf.utils")

local function all_but_first(tbl)
   local result = {}
   for i=2, #tbl do
      result[#result+1] = tbl[i]
   end
   return result
end

local NodeTypes = {}

local mt = {}

local base_mt = {}

function base_mt:children()
   return {}
end

function base_mt:type()
   return self[1]
end

function base_mt:is_leaf()
   return self[1] == "leaf"
end

function base_mt:iter_rest()
   local f, s, i = ipairs(self)
   return f, s, i + 1 -- skip ID tag
end

function base_mt:first_child()
   local c = self:children()
   return c[#c]
end

function base_mt:last_child()
   local c = self:children()
   return c[#c]
end

function base_mt:nth_child(i)
   local c = self:children()
   return c[i]
end

function base_mt:replace_with(other, params)
   local prefix
   if params.preserve_prefix then
      prefix = self:prefix()
   end

   utils.replace_table(self, other)

   if prefix then
      self:set_prefix(prefix)
   end

   return self
end

function base_mt:prefix()
   local o = self[2]

   if o then
      return o:prefix()
   end

   return nil
end

function base_mt:set_prefix(prefix)
   local o = self[2]

   if o then
      o:set_prefix(prefix)
   end

   return self
end

local find_visitor = {}
function find_visitor:new(_type, nesting)
   return setmetatable({ _type = _type, depth = 0, nesting = nesting or 0 }, { __index = find_visitor })
end
function find_visitor:visit_node(node, visit)
   if node[1] == self._type then
      return node
   end

   self.depth = self.depth + 1
   local n =  visit(self, node, visit)
   self.depth = self.depth - 1

   if n then
      if self.nesting > 0 then
         self.nesting = self.nesting - 1
         return node
      end

      return n
   end

   return nil
end
function find_visitor:visit_leaf(leaf)
   if leaf[1] == self._type then
      return leaf
   end
end

function base_mt:find_child_of_type(_type, nesting)
   return visitor.visit(find_visitor:new(_type, nesting), self)
end

function base_mt:__tostring()
   local string_io = {
      stream = "",
      write = function(self, s)
         self.stream = self.stream .. s
      end
   }
   tree_utils.dump(self, string_io)
   return string_io.stream
end

function base_mt:as_code(params)
   params = params or {}
   local string_io = {
      stream = "",
      write = function(self, s)
         self.stream = self.stream .. s
      end
   }
   local v = visitors.code_convert_visitor:new(string_io, params)
   visitor.visit(v, self)
   return string_io.stream
end

function NodeTypes:mknode(name, meta)
   for func_name, func in pairs(base_mt) do
      if not meta[func_name] then
         meta[func_name] = func
      end
   end

   self[name] = function(...)
      return setmetatable(meta.init(...),
                          {
                             __index = meta,
                             __tostring = meta.__tostring
                          })
   end
end

mt.program = {}
function mt.program.init(children, l_eof)
   return { "program", children, l_eof }
end
function mt.program:children()
   return self[2]
end

mt.if_block = {}
function mt.if_block.init(nodes)
   return { "if_block", unpack(nodes) }
end
function mt.if_block:children()
   local c = {}
   for _, v in ipairs(self[2]) do
      if not v[1] == "leaf" then
         c[#c+1] = v
      end
   end
   return c
end

mt.while_block = {}
function mt.while_block.init(l_while, cond, l_do, children, l_end)
   return { "while_block", l_while, cond, l_do, children, l_end }
end
function mt.while_block:children()
   return self[4]
end

mt.do_block = {}
function mt.do_block.init(l_do, children, l_end)
   return { "do_block", l_do, children, l_end }
end
function mt.while_block:children()
   return self[3]
end

mt.numeric_for_range = {}
function mt.numeric_for_range.init(var_name, l_equals, start_expr, l_comma_a, end_expr, l_comma_b, step_expr)
   return { "numeric_for_range", var_name, l_equals, start_expr, l_comma_a, end_expr, l_comma_b or nil, step_expr or nil }
end

mt.generic_for_range = {}
function mt.generic_for_range.init(variables, l_in, generators)
   return { "generic_for_range", variables, l_in, generators }
end

mt.generic_for_variables = {}
function mt.generic_for_variables.init(vars)
   return { "generic_for_variables", vars }
end

mt.generic_for_generators = {}
function mt.generic_for_generators.init(generators)
   return { "generic_for_generators", generators }
end

mt.for_block = {}
function mt.for_block.init(l_for, for_range, l_do, children, l_end)
   return { "for_block", l_for, for_range, l_do, children, l_end }
end
function mt.for_block:children()
   return self[5]
end

mt.repeat_statement = {}
function mt.repeat_statement.init(l_repeat, children, l_until, cond)
   return { "repeat_statement", l_repeat, children, l_until, cond }
end

mt.function_declaration = {}
function mt.function_declaration.init(l_function, name, children, l_end)
   return { "function_declaration", l_function, name, children, l_end }
end
function mt.function_declaration:make_local(l_local)
   local Codegen = require("yalf.parser.codegen")

   if self:is_local() then
      return
   end
   if not l_local then
      l_local = Codegen.gen_keyword("local")
   end
   table.insert(self, 2, l_local)
end
function mt.function_declaration:make_global()
   if not self:is_local() then
      return
   end
   table.remove(self, 2)
end
function mt.function_declaration:is_local()
   return #self == 6 and self[2].value == "local"
end
function mt.function_declaration:declarer()
   local suff = self[3]
   return suff:declarer()
end
function mt.function_declaration:set_declarer(declarer, method)
   local suff = self[3]
   suff:set_declarer(declarer, method)
   return self
end
function mt.function_declaration:name()
   local suff = self[3]
   return suff:name()
end
function mt.function_declaration:full_name()
   local suff = self[3]
   return suff:as_code({no_whitespace=true})
end
function mt.function_declaration:is_method()
   local suff = self[3]
   return suff:is_method()
end
function mt.function_declaration:arguments()
   local body = self[4]
   return body:arguments()
end

function NodeTypes.function_declaration__local(l_local, n_function_declaration)
   n_function_declaration:make_local(l_local)
   return n_function_declaration
end

mt.local_assignment = {}
function mt.local_assignment.init(l_local, assign)
   return { "local_assignment", l_local, assign }
end

mt.label = {}
function mt.label.init(label)
   return { "label", label }
end

mt.return_statement = {}
function mt.return_statement.init(l_return, expr_list)
   return { "return_statement", l_return, expr_list }
end
function mt.return_statement:remove(i)
   return self[3]:remove(i)
end
function mt.return_statement:append(expr)
   self[3]:append(expr)
end
function mt.return_statement:children()
   return self[3]:children()
end

mt.break_statement = {}
function mt.break_statement.init(l_break)
   return { "break_statement", l_break }
end

mt.goto_statement = {}
function mt.goto_statement:get_label()
   return self[2]:get_value()
end
function mt.goto_statement:set_label(label)
   self[2]:set_value(label)
   return self
end
mt.goto_statement = {}
function mt.goto_statement.init(l_goto, label)
   return { "goto_statement", l_goto, label }
end

mt.call_statement = {}
function mt.call_statement.init(expr)
   return { "call_statement", expr }
end

mt.variable_list = {}
function mt.variable_list.init(lhs)
   return lhs
end

mt.value_list = {}
function mt.value_list.init(rhs)
   return rhs
end

mt.assignment_statement = {}
function mt.assignment_statement.init(lhs, l_equals, rhs)
   if rhs then
      assert(l_equals)
   end
   return { "assignment_statement", lhs, l_equals or nil, rhs or nil }
end

mt.parenthesized_expression = {}
function mt.parenthesized_expression.init(l_lparen, expr, l_rparen)
   return { "parenthesized_expression", l_lparen, expr, l_rparen }
end

mt.statement_with_semicolon = {}
function mt.statement_with_semicolon.init(stmt, semicolon)
   return { "statement_with_semicolon", stmt, semicolon }
end

mt.expression = {}
function mt.expression.init(ops_and_numbers)
   return { "expression", unpack(ops_and_numbers) }
end

mt.member_expression = {}
function mt.member_expression.init(l_dot_or_colon, id)
   return { "member_expression", l_dot_or_colon, id }
end
function mt.member_expression:is_method()
   return self[2].value == ":"
end
function mt.member_expression:member()
   return self[3]
end

mt.index_expression = {}
function mt.index_expression.init(l_lbracket, expr, l_rbracket)
   return { "index_expression", l_lbracket, expr, l_rbracket }
end

mt.call_expression = {}
function mt.call_expression.init(l_lparen, arglist, l_rparen)
   return { "call_expression", l_lparen, arglist, l_rparen }
end

mt.table_call_expression = {}
function mt.table_call_expression.init(expr)
   return { "table_call_expression", expr }
end

mt.string_call_expression = {}
function mt.string_call_expression.init(l_str)
   return { "string_call_expression", l_str }
end

mt.suffixed_expression = {}
function mt.suffixed_expression.init(nodes)
   return { "suffixed_expression", unpack(nodes) }
end
function mt.suffixed_expression:children()
   return all_but_first(self)
end
function mt.suffixed_expression:name()
   local last = self:last_child()
   if not last then
      return self:first_child().value
   end
   if last[1] ~= "member_expression" then
      return nil
   end
   return last:member().value
end
function mt.suffixed_expression:is_method()
   local last = self:last_child()
   if not last then
      return self:first_child().value
   end
   if last[1] ~= "member_expression" then
      return nil
   end
   return last:is_method()
end
function mt.suffixed_expression:declarer()
   if #self[2] == 1 then
      return nil
   end

   local decl = self[2][1].value -- TODO

   local last = ""

   for i=2,#self[2]-1 do
      local v = self[2][i]
      if v[1] ~= "member_expression" then
         return nil
      end
      decl = decl .. v:member().value
   end

   decl = decl .. last

   return decl
end
function mt.suffixed_expression:set_declarer(declarer, method)
   local Codegen = require("yalf.parser.codegen")

   if method == nil then
      method = self:is_method()
   end

   local name = self:name()
   local new = Codegen.gen_function_ident(name, declarer, method)
   self:replace_with(new, {preserve_prefix=true})
   return self
end

local function remove_in_comma_list(node, i, braces)
   braces = braces or 0
   local ind = i * 2 + braces
   if not node[ind] then
      return nil
   end

   local expr
   print("remove",ind, #node, braces, 2 + braces * 2)

   if #node == 2 + braces * 2 then
      -- `single_arg` -> ``
      expr = table.remove(node, ind)
      print(1)
   elseif ind == #node - braces then
      -- `first, second` -> `first`
      expr = table.remove(node, ind)
      table.remove(node, ind-1) -- comma
      print(2)
   else
      -- `first, second, third` -> `first, third`
      expr = table.remove(node, ind)
      table.remove(node, ind) -- comma
      print(3)
   end

   return expr
end

local function insert_in_comma_list(node, i, item, braces)
   braces = braces or 0
   local Codegen = require("yalf.parser.codegen")

   print(i,#node,braces)
   if i then
      i = i * 2 + braces
   else
      i = #node + 1 - braces
   end
   print("get", i,#node-braces)

   if #node == 1 + 2 * braces then
      table.insert(node, #node+1-braces, item)
   else
      table.insert(node, i, Codegen.gen_symbol(","):set_prefix(" "))
      table.insert(node, i+1, item)
   end
end

local function clear(self)
   for i=2,#self do
      self[i] = nil
   end
end

mt.statement_list = {}
function mt.statement_list.init(stmts)
   return { "statement_list", unpack(stmts) }
end
function mt.statement_list:children()
   return all_but_first(self)
end
function mt.statement_list:remove(i)
   return table.remove(self, i + 1)
end
function mt.statement_list:insert(stmt, i)
   if i then
      if i < 1 or i > #self then
         return
      end
      table.insert(self, i + 1, stmt)
   else
      table.insert(self, stmt)
   end
end
function mt.statement_list:clear()
   clear(self)
end

mt.ident_list = {}
function mt.ident_list.init(idents)
   return { "ident_list", unpack(idents) }
end
function mt.ident_list:children()
   return all_but_first(self)
end
function mt.ident_list:remove(i)
   return remove_in_comma_list(self, i)
end
function mt.ident_list:clear()
   clear(self)
end
function mt.ident_list:insert(ident, i)
   local Codegen = require("yalf.parser.codegen")

   if type(ident) == "string" then
      ident = Codegen.gen_ident(ident)
   end

   insert_in_comma_list(self, i, ident)
end

mt.expression_list = {}
function mt.expression_list.init(exprs)
   return { "expression_list", unpack(exprs) }
end
function mt.expression_list:children()
   return all_but_first(self)
end
function mt.expression_list:remove(i)
   return remove_in_comma_list(self, i)
end
function mt.expression_list:insert(expr, i)
   local Codegen = require("yalf.parser.codegen")

   if type(expr) == "string" then
      expr = Codegen.gen_expression(expr)
   end

   insert_in_comma_list(self, i, expr)
end
function mt.expression_list:clear()
   clear(self)
end
function mt.expression_list:children()
   local c = {}
   for i=2,#self,2 do
      c[#c+1] = self[i]
   end
   return c
end

mt.constructor_key = {}
function mt.constructor_key.init(l_lbracket, entries, l_rbracket)
   return { "constructor_key", l_lbracket, entries, l_rbracket }
end

mt.key_value_pair = {}
function mt.key_value_pair.init(key, l_equals, value)
   return { "key_value_pair", key, l_equals, value }
end

mt.constructor_expression = {}
function mt.constructor_expression.init(l_lbracket, body, l_rbracket)
   local t = { "constructor_expression", l_lbracket }
   for _, v in ipairs(body) do
      t[#t+1] = v
   end
   t[#t+1] = l_rbracket
   return t
end
function mt.constructor_expression:children()
   local c = {}
   for i=3,#self-1,2 do
      c[#c+1] = self[i]
   end
   return c
end
function mt.constructor_expression:remove(i)
   return remove_in_comma_list(self, i, 1)
end
function mt.constructor_expression:clear()
   local l_rbrace = self[#self]
   assert(l_rbrace.value == "}")
   for i=3,#self do
      self[i] = nil
   end
   self[4] = l_rbrace
end
function mt.constructor_expression:insert(kv_pair, i)
   local Codegen = require("yalf.parser.codegen")

   if type(kv_pair) == "table" and type(kv_pair[1]) == "string" then
      kv_pair = Codegen.gen_key_value_pair(kv_pair[1], kv_pair[2])
   elseif type(kv_pair) ~= "table" then
      kv_pair = Codegen.gen_key_value_pair(kv_pair)
   end

   insert_in_comma_list(self, i, kv_pair, 1)
end

mt.function_parameters_and_body = {}
function mt.function_parameters_and_body.init(l_lparen, params, l_rparen, body)
   return { "function_parameters_and_body", l_lparen, params, l_rparen, body }
end
function mt.function_parameters_and_body:arguments()
   return self[3]
end

mt.function_expression = {}
function mt.function_expression.init(l_function, body, l_end)
   return { "function_expression", l_function, body, l_end }
end

mt.leaf = {}
function mt.leaf.init(_type, value, prefix, line, column)
   return {
      [1] = "leaf",
      type = _type,
      value = value,
      _prefix = prefix or {},
      line = line or -1,
      column = column or -1,
   }
end
function mt.leaf:prefix_to_string()
   local prefix = ""
   for _, v in ipairs(self._prefix) do
      prefix = prefix .. v.Data
   end
   return prefix
end
function mt.leaf:as_string(no_whitespace)
   if no_whitespace then
      return tostring(self.value)
   end

   return self:prefix_to_string() .. tostring(self.value)
end
function mt.leaf:prefix()
   return self._prefix
end
function mt.leaf:set_prefix(prefix)
   if type(prefix) == "string" then
      local Codegen = require("yalf.parser.codegen")
      prefix = Codegen.make_prefix(prefix)
   end
   self._prefix = prefix
   return self
end

for k, v in pairs(mt) do
   NodeTypes:mknode(k, v)
end

NodeTypes.mt = mt

function NodeTypes.on_hotload(old, new)
   for k, v in pairs(old.mt) do
      utils.replace_table(v, new.mt[k])
   end
end

return NodeTypes
