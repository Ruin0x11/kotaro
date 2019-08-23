local utils = require("kotaro.utils")
local code_convert_visitor = {}

function code_convert_visitor:new(stream, params)
   local o = setmetatable({ buf = utils.string_buffer(), params = params or {}, first_prefix = false }, { __index = code_convert_visitor })
   o.stream = stream or { stream = io, write = function(t, ...) t.stream.write(...) end }
   return o
end

function code_convert_visitor:visit_node(node, visit)
   visit(self, node, visit)
end

function code_convert_visitor:visit_leaf(leaf)
   local no_ws = self.params.no_whitespace
   if not self.first_prefix then
      self.first_prefix = true
      if self.params.no_leading_whitespace then
         no_ws = true
      end
   end
   if not no_ws then
      self.buf:append(leaf._prefix)
   end
   self.buf:append(leaf.value)
end

return code_convert_visitor
