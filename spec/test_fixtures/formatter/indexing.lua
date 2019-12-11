tbl [
   1
    ] = "test"
tbl [
   5+ 6 ] = function()
   return true
end
-- Result --
tbl[1] = "test"
tbl[5 + 6] = function() return true end
