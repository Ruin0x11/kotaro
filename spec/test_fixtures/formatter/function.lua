function single() return "test"
end

function test ( param1,
                param2  )
   method()
   return 1
end

local tbl = {}
function tbl:method()
   self.value = 1
end

function tbl:method2() return 12345678 < 12345678 + 1 end
-- Result --
function single() return "test" end

function test(param1, param2)
   method()
   return 1
end

local tbl = {}
function tbl:method() self.value = 1 end

function tbl:method2()
  return 12345678 < 12345678 + 1
end
