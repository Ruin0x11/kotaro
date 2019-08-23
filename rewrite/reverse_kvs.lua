local Codegen = require("kotaro.parser.codegen")

local reverse_kvs = {}

function reverse_kvs:applies_to(node)
   return node:type() == "constructor_expression"
end
function reverse_kvs:execute(node)
   for _, child in node:iter_depth_first() do
      if child:type() == "key_value_pair" and child:value():is_simple() then
         local key = child:key():evaluate()
         local value = child:value():evaluate()
         node:modify_index(key, nil)
         node:modify_index("i", "i")
      end
   end
   node:changed()
end

return require("rewrite.lib.refactoring")(reverse_kvs)
