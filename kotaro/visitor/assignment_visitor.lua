local visitor = require("kotaro.visitor")

local assignment_visitor = {}

function assignment_visitor:new()
   return setmetatable({ scopes = {} }, { __index = assignment_visitor })
end

function assignment_visitor:visit_leaf(node)
end

local function is_unpacking(expr)
   return expr:is_dots() or expr:is_function_call()
end

local function new_scope()
   return {
      vars = {},
      labels = {},
      gotos = {}
   }
end

function assignment_visitor:enter_scope()
   self.scopes[#self.scopes+1] = new_scope()
end

function assignment_visitor:leave_scope()
   local last_scope = self.scopes[#self.scopes]
   local prev_scope = self.scopes[#self.scopes-1]
   self.scopes[#self.scopes] = nil
end

-- Plundered from luacheck.
function assignment_visitor:register_set_variables(node)
   node.set_variables = {}

   -- node:dump(io.stdout)

   local is_init = node:is_local()
   local unpacking_item

   local rhs = node:rhs()
   if rhs then
      local last_rhs_item = rhs:last_child()
      if is_unpacking(last_rhs_item) then
         -- rhs is a statement like a call or dots that can be unpacked
         unpacking_item = last_rhs_item
      end
   end

   local secondaries -- Array of values unpacked from rightmost rhs item.

   local lhs = node:lhs()
   if unpacking_item and (#lhs:children() > #rhs:children()) then
      secondaries = {}
   end

   local rhs_children = rhs and rhs:children() or {}
   for i, lhs_node in ipairs(lhs:children()) do
      local variable_value

      if lhs_node:is_single_ident() then
         local variable_name = lhs_node:name():raw_value()

         -- BUG: ident_list includes commas in :children() but
         -- expression_list does not
         variable_value = rhs_children[i] or unpacking_item

         print(variable_name, variable_value and variable_value:as_code())
         node.set_variables[variable_name] = variable_value
      end

      if secondaries and i >= #rhs_children then
         if variable_value then
            variable_value.secondaries = secondaries
            secondaries[#secondaries+1] = variable_value
         else
            -- If one of secondary values is assigned to a global or index,
            -- it is considered used.
            secondaries.used = true
         end
      end
   end
end

function assignment_visitor:visit__assignment_statement(node)
   -- self:register_set_variables(node)
end

function assignment_visitor:visit_node(node, visit)
   self:enter_scope()
   visit(self, node, visit)
   self:leave_scope()
end

return assignment_visitor
