local class = require '3rdparty.middleclass'

local RingBuffer = class('RingBuffer')

function RingBuffer:initialize(depth)
  self.slot={}
  self.cursor=1
  self.depth=depth
end
  
function RingBuffer:last()
  return self.slot[self.cursor] 
end

function RingBuffer:previous(i)
  local depth = self.depth
  if i > depth then error("ring overflow") end
  local n = self.cursor - i
  if n < 1 then n = n + depth end
  return self.slot[n]
end

function RingBuffer:push(val)
  local c = self.cursor
  local depth = self.depth      
  if c == depth then
    c = 1
  else
    c = c + 1
  end      
  self.slot[c] = val
  self.cursor = c
end

-- local function test()  
--   local r = RingBuffer(10)
--   for i=1,10 do
--     local v = string.format("Message #%d", i)
--     print('PUSH: ' .. v)
--     r:push(v)
--   end
--   print("LAST: " .. r:last())
--   for i=1,9 do
--     print('PREVIOUS(' .. i ..'): ' .. r:previous(i))
--   end
--   print()
-- end

-- test()

return RingBuffer
