tbl [
   1
    ] = "test"
tbl [
   5+ 6 ] = function()
   return 1
end
-- Result --
tbl[1] = "test"
tbl[5 + 6] = function() return 1 end
