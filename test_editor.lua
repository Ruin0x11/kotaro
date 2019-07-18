local rth = require("test_refactoring")

local test = {
   params = {
      line = { type = "current_line" },
      col = { type = "current_column" },
   }
}

function test:determine_input_files(params, opts)
   return opts.input_files
end

function test:before_execute(ast, params, opts)
end

function test:execute(ast, params, opts)
   local stmt = ast:find_child_of_type_at_loc(params.line, params.col, "assignment_statement")
   if not stmt then return nil end

   local list = stmt:find_parent_of_type("statement_list")
   if not list then return nil end

   local s = stmt:clone()
   list:insert_node(s, 1)
   list:changed()

   return ast
end

function test:after_execute(ast, params, opts)
end

return test

