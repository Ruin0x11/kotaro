function tbl:method2()
   return 123456789
      < 123456789 + 1
end
function tbl:method3() return  123456789 < 123456789 + 1  end
-- Result --
function tbl:method2()
  return 123456789 < 123456789 + 1
end
function tbl:method3()
  return 123456789 < 123456789 + 1
end
