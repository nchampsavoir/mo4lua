local ffi = require "ffi"
local Buffer = require "3rdparty.buffer"

local uint64 = ffi.typeof("uint64_t")
local int16ptr = ffi.typeof("int16_t*")
local uint16ptr = ffi.typeof("int16_t*")
local int32ptr = ffi.typeof("int32_t*")
local uint32ptr = ffi.typeof("uint32_t*")
local int64ptr = ffi.typeof("int64_t*")
local uint64ptr = ffi.typeof("uint64_t*")
local floatptr = ffi.typeof("float*")
local doubleptr = ffi.typeof("double*")

local int32store = ffi.typeof("int32_t[1]")
local uint32store = ffi.typeof("uint32_t[1]")
local uint64store = ffi.typeof("uint64_t[1]")

local function compliment8(value)
  return value < 0x80 and value or -0x100 + value
end

local function compliment16(value)
  return value < 0x8000 and value or -0x10000 + value
end

local function compliment32(value)
  return value < 0x80000000 and value or -0x100000000 + value
end

-- offset is the current offset in bytes from the begining of buffer starting at 0
-- bitshift is the position in bits relative to the offset starting at 1   
    
-- decode_uint1
function Buffer:read_uint1(location_in_bits)
  local offset = bit.rshift(location_in_bits, 3)
  local bitshift = bit.band(location_in_bits, 7)      
  return bit.band(bit.rshift(self.tbuffer.data[offset], 7 - bitshift), 1) -- (8 - 1 - bitshift)
end

-- read_uint2
function Buffer:read_uint2(location_in_bits)
  local offset = bit.rshift(location_in_bits, 3)
  local bitshift = bit.band(location_in_bits, 7)
  return bit.band(bit.rshift(self.tbuffer.data[offset], 6 - bitshift), 3) -- (8 - 2 - bitshift)
end

-- read_uint3
function Buffer:read_uint3(location_in_bits)
  local offset = bit.rshift(location_in_bits, 3)
  local bitshift = bit.band(location_in_bits, 7)
return bit.band(bit.rshift(self.tbuffer.data[offset], 5 - bitshift), 7) -- (8 - 3 - bitshift)
end

-- read_uint4
function Buffer:read_uint4(location_in_bits)
  local offset = bit.rshift(location_in_bits, 3)
  local bitshift = bit.band(location_in_bits, 7)  
  return bit.band(bit.rshift(self.tbuffer.data[offset], 4 - bitshift), 0xF) -- (8 - 4 - bitshift)
end

-- read_uint3
function Buffer:read_uint5(location_in_bits)
  local offset = bit.rshift(location_in_bits, 3)
  local bitshift = bit.band(location_in_bits, 7)
  return bit.band(bit.rshift(self.tbuffer.data[offset], 3 - bitshift), 0x1F) -- (8 - 5 - bitshift)
end

-- read_uint6
function Buffer:read_uint6(location_in_bits)
  local offset = bit.rshift(location_in_bits, 3)
  local bitshift = bit.band(location_in_bits, 7)
  return bit.band(bit.rshift(self.tbuffer.data[offset], 2 - bitshift), 0x3F) -- (8 - 6 - bitshift)
end

-- read_uint7
function Buffer:read_uint7(location_in_bits)
  local offset = bit.rshift(location_in_bits, 3)
  local bitshift = bit.band(location_in_bits, 7)
  return bit.band(bit.rshift(self.tbuffer.data[offset], 1 - bitshift), 0x7F) -- (8 - 7 - bitshift)
end

-- read_uint8
function Buffer:read_uint8(location_in_bits)
  local offset = bit.rshift(location_in_bits, 3)  
  return bit.band(self.tbuffer.data[offset], 0xFF)
end

-- read_uint9
function Buffer:read_uint9(location_in_bits)
  local offset = bit.rshift(location_in_bits, 3)
  return bit.bor(bit.lshift(self:read_uint1(location_in_bits), 8), self.tbuffer.data[offset + 1])
end

-- read_uint10
function Buffer:read_uint10(location_in_bits)
  local offset = bit.rshift(location_in_bits, 3)
  return bit.bor(bit.lshift(self:read_uint2(location_in_bits), 8), self.tbuffer.data[offset + 1])
end

-- read_uint11
function Buffer:read_uint11(location_in_bits)
  local offset = bit.rshift(location_in_bits, 3)
  return bit.bor(bit.lshift(self:read_uint3(location_in_bits), 8), self.tbuffer.data[offset + 1])
end

-- read_uint12
function Buffer:read_uint12(location_in_bits)
  local offset = bit.rshift(location_in_bits, 3)
  return bit.bor(bit.lshift(self:read_uint4(location_in_bits), 8), self.tbuffer.data[offset + 1])
end

-- read_uint13
function Buffer:read_uint13(location_in_bits)
  local offset = bit.rshift(location_in_bits, 3)
  return bit.bor(bit.lshift(self:read_uint5(location_in_bits), 8), self.tbuffer.data[offset + 1])
end

-- read_uint14
function Buffer:read_uint14(location_in_bits)
  local offset = bit.rshift(location_in_bits, 3)
  return bit.bor(bit.lshift(self:read_uint6(location_in_bits), 8), self.tbuffer.data[offset + 1])
end

-- read_uint15
function Buffer:read_uint15(location_in_bits)
  local offset = bit.rshift(location_in_bits, 3)
  return bit.bor(bit.lshift(self:read_uint7(location_in_bits), 8), self.tbuffer.data[offset + 1])
end

-- read_uint16
function Buffer:read_uint16(location_in_bits)
  local offset = bit.rshift(location_in_bits, 3)
  local b = ffi.cast(uint16ptr, self.tbuffer.data + offset)
  return bit.rshift(bit.bswap(b[0]), 16)
end

-- read_int16
function Buffer:read_int16(location_in_bits)  
  return compliment16(self:read_uint16(location_in_bits))
end

-- read_uint16 Little Endian
function Buffer:read_uint16LE(location_in_bits)    
  local offset = bit.rshift(location_in_bits, 3)  
  local b = ffi.cast(uint16ptr, self.tbuffer.data + offset)  
  return bit.band(b[0], 0xFFFF)
end

-- read_uint16
function Buffer:read_int16LE(location_in_bits)
  local offset = bit.rshift(location_in_bits, 3)  
  local b = ffi.cast(int16ptr, self.tbuffer.data + offset)  
  return bit.band(b[0], 0xFFFF)
end

-- read_uint32 Big Endian
function Buffer:read_uint32(location_in_bits)  
  local offset = bit.rshift(location_in_bits, 3)
  local offset = bit.rshift(location_in_bits, 3)  
  local b = ffi.cast(uint32ptr, self.tbuffer.data + offset)
  return bit.bswap(b[0])
end

-- read_uint32 Little Endian
function Buffer:read_int32(location_in_bits)    
  return compliment32(self:read_uint32(location_in_bits))
end

-- read_uint32 Little Endian
function Buffer:read_int32LE(location_in_bits)    
  local offset = bit.rshift(location_in_bits, 3)
  local b = ffi.cast(int32ptr, self.tbuffer.data + offset)
  return b[0]
end

-- read_uint40
function Buffer:read_uint40(location_in_bits)    
  return bit.rshift(self:read_uint64(location_in_bits), 24)
end

-- read_uint48
function Buffer:read_uint48(location_in_bits)    
  return bit.rshift(self:read_uint64(location_in_bits), 16) 
end

-- read_uint56
function Buffer:read_uint56(location_in_bits)      
  return bit.rshift(self:read_uint64(location_in_bits), 8)
end

-- read_uint64
function Buffer:read_uint64(location_in_bits)  
  return bit.bswap(self:read_uint64LE(location_in_bits))  
end

-- read_uint64 Little Endian
function Buffer:read_uint64LE(location_in_bits)      
  local offset = bit.rshift(location_in_bits, 3)
  local int64 = ffi.cast(uint64ptr, self.tbuffer.data + offset)   
  return int64[0]  
end

-- read binary data
function Buffer:read_binary(location_in_bits, length_in_bits)
  local offset = bit.rshift(location_in_bits, 3)
  local length = bit.rshift(length_in_bits, 3)
  return ffi.string(self.tbuffer.data + offset, length)
end

function Buffer:read_float(location_in_bits)
  local offset = bit.rshift(location_in_bits, 3)
  local int32 = ffi.cast(uint32ptr, self.tbuffer.data + offset)
  int32[0] = bit.bswap(int32[0])
  local f = ffi.cast(floatptr, int32)
  return f[0] or 0
end

function Buffer:read_double(location_in_bits)  
  local offset = bit.rshift(location_in_bits, 3)
  local int64 = ffi.cast(int64ptr, self.tbuffer.data + offset)
  int64[0] = bit.bswap(int64[0])
  local d = ffi.cast(doubleptr, int64)
  return d[0] or 0
end

function Buffer:append_uint8(num)
  self:append_char_right(bit.band(num, 0xFF))
end

function Buffer:append_uint16(num)
  self:append_char_right(bit.rshift(num, 8))
  self:append_char_right(bit.band(num, 0xFF))
end

function Buffer:append_int32(num)
  local s = int32store()
  s[0] = bit.bswap(num)
  self:append_right(s, 4)
end

function Buffer:append_uint32(num)
  local s = uint32store()
  s[0] = bit.bswap(num)
  self:append_right(s, 4)
end

function Buffer:append_uint64(uint64)
  local s = uint64store()
  s[0] = bit.bswap(uint64)
  self:append_right(s, 8)
end