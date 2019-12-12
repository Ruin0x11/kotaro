if x + 1 == 2 then
y = 2
z = 3
end

if true then
return false
end

if 123456789 < 123456789 + 1 then return true end

if 123456789 < 987654321 and 987654321 < 123456789 then return true end

if 123456789 < 987654321 and (987654321 < 123456789 or true or false) then return true end
-- Result --
if x + 1 == 2 then
   y = 2
   z = 3
end

if true then return false end

if 123456789 < 123456789 + 1 then
  return true
end

if 123456789 < 987654321
  and 987654321 < 123456789
then
  return true
end

if 123456789 < 987654321
  and (987654321 < 123456789
       or true
       or false)
then
  return true
end
