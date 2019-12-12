function tbl:method()
   a = 1
end

self.field = math.max(math.max(add, 0), self:method("field"))

do
self.field = math.max(math.max(add, 0), self:method("field"))
end
-- Result --
function tbl:method() a = 1 end

self.field = math.max(math.max(add, 0),
                      self:method("field"))

do
  self.field =
    math.max(math.max(add, 0),
             self:method("field"))
end
