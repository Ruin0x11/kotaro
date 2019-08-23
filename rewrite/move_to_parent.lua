local move_to_parent = {}

function move_to_parent:new(inside, field, to_field)
   return setmetatable({inside=inside,field=field,to_field=to_field}, {__index=move_to_parent})
end

function move_to_parent:applies_to(node)
   if node:type() ~= "constructor_expression" then
      return false
   end

   local ctc = node:index(self.inside)
   if not ctc then
      return false
   end

   local cons = ctc:primary_expression()

   return cons:type() == "constructor_expression" and cons:index(self.field)
end

function move_to_parent:execute(node)
   local ctc = node:index(self.inside)
   local cons = ctc:primary_expression()
   local skills = cons:index(self.field)
   cons:modify_index(self.field)
   node:modify_index(self.to_field, skills)
   node:changed()
end

return {
   params = {
      inside = "string",
      field = "string",
      to_field = "string"
   },

   execute = function(self, ast, params)
      return ast:rewrite(move_to_parent:new(params.inside,params.field,params.to_field))
   end
}
