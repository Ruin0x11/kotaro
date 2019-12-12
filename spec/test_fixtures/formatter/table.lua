a = {1, 2, 3 }; b = {

   "string",false, { 1,2, 3 } }
c = {a = function()  return    1 end
    }
d = {b = function() return 1 end, 2, ["asd"] = "c" }
e =
   {
   a = function(
            param1,
            param2)
        return param1 + param2 end }
-- Result --
a = {1, 2, 3}
b = {"string", false, {1, 2, 3}}
c = {a = function() return 1 end}
d = {
  b = function() return 1 end,
  2,
  ["asd"] = "c"
}
e = {
  a = function(param1, param2)
    return param1 + param2
  end
}
