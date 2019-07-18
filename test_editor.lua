local rth = require("test_refactoring")

local test = {
   params = {
      line = { type = "current_line" },
      col = { type = "current_column" },
      amount = { type = "number" },
   }
}

local add_integer = {}

function add_integer:new(add)
   return setmetatable({ add = add }, { __index = add_integer })
end

function add_integer:applies_to(node)
   return node:type() == "leaf"
      and node.leaf_type == "Number"
      or node.leaf_type == "Boolean"
end

function add_integer:execute(node)
   local val = node:evaluate()

   if type(val) == "boolean" then
      node:set_value(not val)
   else
      node:set_value(val + self.add)
   end
end

function test:determine_input_files(params, opts)
   return opts.input_files
end

function test:before_execute(ast, params, opts)
end

function test:execute(ast, params, opts)
   return ast:rewrite(add_integer:new(params.amount))
end

function test:after_execute(ast, params, opts)
end

return test

