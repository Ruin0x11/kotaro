return function(rw)
   local rewrite = {}
   rewrite.execute = function(self, ast) return ast:rewrite(rw) end
   return rewrite
end
