obj:method_1( 1):
   method_2("dood")
   :method_3(false)

object:method_1(1):very_very_long_method_2("dood"):method_3(false):method_1(1):very_very_long_method_3("dood"):method_3(false)

do
obj:method_1(1):method_2("dood"):method_3(false):method_4(true)
end
-- Result --
obj:method_1(1):method_2("dood"):method_3(false)

object:method_1(1):very_very_long_method_2("dood")
  :method_3(false):method_1(1)
  :very_very_long_method_3("dood"):method_3(false)

do
  obj:method_1(1):method_2("dood")
    :method_3(false):method_4(true)
end
