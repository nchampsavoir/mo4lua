--
--  Demo parser for CCSDS SPACE PACKETS
--
local ffi = require "ffi"
local Buffer = require "3rdparty.buffer"
local class = require '3rdparty.middleclass'
local RingBuffer = require "ringbuffer"
require "bitbuffer"

-- CCSDS Space Packet Protocol Header Defintion
ffi.cdef[[
typedef struct { 
    uint8_t version_number; 
    uint8_t packet_type; 
    uint8_t sec_header_flag; 
    uint16_t apid; 
    uint8_t seq_flags; 
    uint16_t seq_count; 
    uint16_t length; 
    } space_packet_header_t;
]]

-- PUS Header Defintion
ffi.cdef[[
typedef struct {     
    uint8_t version_number; 
    uint8_t service_type; 
    uint8_t service_subtype; 
    uint8_t subcounter; 
    uint8_t destination_id; 
    uint8_t time1; 
    uint8_t time2; 
    uint8_t time3; 
    uint8_t time4; 
    uint8_t time5; 
    uint8_t time6; 
    uint8_t time7; 
    } pus_header_t;
]]

-- Optional PUS Packet Time Status Defintion
ffi.cdef[[
typedef struct {     
    uint8_t sync_state; 
    uint8_t quality_of_time; 
    } time_status_t;
]]

-- Optional Packet Error Control Code Definition
ffi.cdef[[
typedef struct {
    uint8_t crc1;
    uint8_t crc2;
    } packet_error_control_t;
]]

local SPACE_PACKET_HEADER_SIZE = 6
local PUS_HEADER_SIZE = 13

local Decom = class('Decom')

--- Create a new decommutation context.
-- @modelfile a path to the decommutation model in lua format
-- @pus process pus secondary header if present
-- @maxbufsize maximum amount of memory allocated to the internal buffer
-- #depth depth of the decommutation history (i.E. the number of available 'previous' values)
-- @return Decom instance.
function Decom:initialize(modelfile, options) 
    local options = options or {}
    self.pus = options.pus or false
    self.maxbufsize = options.maxbufsize or 200000        
    self.space_packet_header = ffi.new("space_packet_header_t")
    self.pus_header = ffi.new("pus_header_t")
    self.time_status = ffi.new("time_status_t")
    self.error_control = ffi.new("packet_error_control_t")    
    self.buffer = Buffer()    
    self.secondary_header_length = 0
    self.start_of_packet = 0    
    self.apid_counts = {}       
    self.total_packets = 0    
    self.debug = options.debug or false
    if modelfile then
        local model, err = io.open(modelfile, "rb")
        if model == nil then
            print("Model file does not exist", err)
            os.exit(1)
        else
            model:close()
        end
        self.decommutation_fn = dofile(modelfile)
        assert(self.decommutation_fn, "Invalid model")
        self.values = {}
        self.history = Decom:make_history(options.depth)
    end
    self:reset()
end

--- Creates a table of ring buffers to hold the N previous values 
-- of each parameter
-- @depth number of previous values to keep in history (default:10)
-- @return an history table
function Decom:make_history(depth)
    local mt = {
        __index = function (t, key)
            local r = RingBuffer(depth or 10)
            t[key] = r
            return r
        end
    }
    local history = {}
    setmetatable(history, mt)
    return history
end


--- Reads a CCSDS Space Packet Header from in the internal buffer
-- at offset *start_of_packet* and stores the result in an internal struct. 
-- @return header size in bytes
function Decom:read_space_packet_header(cursor)

    if self.header_length ~= 0 then return 6 end

    cursor = cursor or self.start_of_packet

    local data = self.space_packet_header    
    local buffer = self.buffer

    if cursor + 6 > buffer:len() then
        return 0
    end    

    local location_in_bits = cursor * 8
    data.version_number  = buffer:read_uint3 (location_in_bits)       -- 3 bits
    data.packet_type     = buffer:read_uint1 (location_in_bits + 3)   -- 1 bit
    data.sec_header_flag = buffer:read_uint1 (location_in_bits + 4)   -- 1 bit
    data.apid            = buffer:read_uint11(location_in_bits + 5)   -- 11 bits    
    data.seq_flags       = buffer:read_uint2 (location_in_bits + 16)  -- 2 bits
    data.seq_count       = buffer:read_uint14(location_in_bits + 18)  -- 14 bits
    data.length          = buffer:read_uint16(location_in_bits + 32)  -- 16bits
    
    return 6
end

--- Check whether the space packet header read by 'read_space_packet_header'
-- appears to be valid
-- @return true if valid, false otherwise
function Decom:packet_is_valid()    
    if self.space_packet_header.version_number ~= 0 then
        print ("bad version: " .. self.space_packet_header.version_number)        
        return false
    end    
    if self.space_packet_header.packet_type ~= 0 then
        print ("bad type: " .. self.space_packet_header.packet_type)        
        return false
    end    
    if self.space_packet_header.length == 0 then
        print ("bad length: " .. self.space_packet_header.length)        
        return false
    end    
    return true
end

-- Outputs the content of the CCSDS Space Packet Header 
-- @out a file object (defaults to io.stdout)
function Decom:write_space_packet_header(out) 
    out = out or io.stdout
    local header = self.space_packet_header
    out:write ("[CCSDS HEADER]\n")
    out:write ("  VERSION: " .. header.version_number .. "\n")
    out:write ("  TYPE: " .. header.packet_type .. "\n")
    out:write ("  SECONDARY HEADER FLAG: " .. header.sec_header_flag .. "\n")
    out:write ("  APID: " .. header.apid .. "\n")
    out:write ("  SEQUENCE FLAGS: " .. header.seq_flags .. "\n")
    out:write ("  SEQ_COUNT: " .. header.seq_count .. "\n")
    out:write ("  LENGTH: " .. header.length .. "\n")    
end

--- Checks whether the current packet has a secondary header
-- @return true if secondary header is present, false otherwise
function Decom:has_secondary_header()
    return self.space_packet_header ~= nil and self.space_packet_header.sec_header_flag ~= 0
end

--- Reads a PUS Secondary Header from in the internal buffer
-- starting right after the primary header and stores 
-- the result in an internal struct. 
-- @return PUS header size in bytes
function Decom:read_pus_header(cursor)    

    if not self.space_packet_header.sec_header_flag then
        return
    end

    if self.secondary_header_length ~= 0 then
        return self.secondary_header_length
    end

    cursor = cursor or self.start_of_packet + 6
    local data = self.pus_header    
    local buffer = self.buffer

    if cursor + 12 > buffer:len() then
        return 0
    end

    local location_in_bits = cursor * 8
    -- 1 bit is spare    
    data.version_number = buffer:read_uint3(location_in_bits + 1) -- 3 bits
    -- bits 4 to 8 are spare
    data.service_type = buffer:read_uint8(location_in_bits + 8) -- 4 bits
    data.service_subtype = buffer:read_uint8(location_in_bits + 16) -- 8 bits
    data.subcounter = buffer:read_uint8(location_in_bits + 24) -- 8 bits
    data.destination_id = buffer:read_uint8(location_in_bits + 32) -- 8 bits
    data.time1 = buffer:read_uint8(location_in_bits + 40) -- 7 * 8 bits
    data.time2 = buffer:read_uint8(location_in_bits + 48)
    data.time3 = buffer:read_uint8(location_in_bits + 56)
    data.time4 = buffer:read_uint8(location_in_bits + 64)
    data.time5 = buffer:read_uint8(location_in_bits + 72)
    data.time6 = buffer:read_uint8(location_in_bits + 80)
    data.time7 = buffer:read_uint8(location_in_bits + 88)

    self.secondary_header_length = 12
    return 12
end

--- Outputs the content of the PUS Secondary Header
-- @out a file object (defaults to io.stdout)
function Decom:write_pus_header(out) 
    out = out or io.stdout
    local header = self.pus_header
    out:write ("[PUS HEADER]" .. "\n")    
    out:write ("  VERSION: " .. header.version_number .. "\n")
    out:write ("  SERVICE TYPE: " .. header.service_type .. "\n")
    out:write ("  SERVICE SUBTYPE: " .. header.service_subtype .. "\n")
    out:write ("  SUBCOUNTER: " .. header.subcounter .. "\n")
    out:write ("  DESTINATION ID: " .. header.destination_id .. "\n")
    out:write ("  TIME1: " .. header.time1 .. "\n")    
    out:write ("  TIME2: " .. header.time2 .. "\n")    
    out:write ("  TIME3: " .. header.time3 .. "\n")    
    out:write ("  TIME4: " .. header.time4 .. "\n")    
    out:write ("  TIME5: " .. header.time5 .. "\n")    
    out:write ("  TIME6: " .. header.time6 .. "\n")    
    out:write ("  TIME7: " .. header.time7 .. "\n")    
end


--- Reads a PUS Time Status from in the internal buffer
-- the result in an internal struct. 
-- @return PUS Time Status size in bytes
function Decom:read_pus_time_status(cursor)     
    local buffer = self.buffer

    cursor = cursor or self.start_of_packet + 6 + 12

    if cursor + 1 > buffer:len() then
        return 0
    end

    self.time_status.sync_state = buffer:read_uint1(cursor, 0) -- 1 bit
    self.time_status.quality_of_time = bit.bor(buffer:read_uint7(cursor, 1), buffer:read_uint8(cursor + 1))  -- 15 bits

    return 1
end

--- Outputs the content of the Time Status 
-- @out a file object (defaults to io.stdout)
function Decom:print_time_status(out)   
    out = out or io.stdout 
    out:write ("[TIME STATUS]" .. "\n") 
    out:write ("  SYNC STATE: " .. self.time_status.sync_state .. "\n")
    out:write ("  QUALITY OF TIME: " .. self.time_status.quality_of_time .. "\n")        
end

--- Reads the Error Control Code at the current cursor position
-- @return Error Contorl size in bytes
function Decom:read_error_control(cursor)    
    local buffer = self.buffer

    if cursor + 2 > buffer:len() then
        return 0
    end
    
    self.error_control.crc1 = buffer:read_uint8(cursor)
    self.error_control.crc2 = buffer:read_uint8(cursor + 1)
     
    return 2
end

--- Outputs the content of the Error Control Code
-- @out a file object (defaults to io.stdout)
function Decom:print_error_control(out)    
    out = out or io.stdout
    out:write ("[ERROR CONTROL CODE]" .. "\n") 
    out:write ("  CRC1: " .. self.error_control.crc1 .. "\n")
    out:write ("  CRC2: " .. self.error_control.crc2 .. "\n")        
end

--- Concatenates binary data to the internal read buffer of the
-- decommutation engine 
function Decom:append(data)    
    if string.len(data) + self.buffer:len() > self.maxbufsize then
        self.buffer:pop_left(self.start_of_packet)
        self.start_of_packet = 0
    end
    self.buffer:append_luastr_right(data)  
end

--- Reads both the primary header and the secondary header 
-- (if present) for the current packet
function Decom:read_headers()
    self:read_space_packet_header()
    if self.pus and self:has_secondary_header() then
        self:read_pus_header()
    end
end

--- Outputs the content of the primary header and 
-- the secondary header (if present)
-- @out a file object (defaults to io.stdout)
function Decom:write_headers(out)    
    self:write_space_packet_header(out)
    if self.pus and self:has_secondary_header() then
        self:write_pus_header(out)
    end
end

--- Returns the content of the packet primary header
-- @return a string of bytes
function Decom:get_header()
    return self.buffer:substr(self.start_of_packet, self.header_length)
end

--- Returns the content of the packet data field
-- @return a string of bytes
function Decom:get_content()
    return self.buffer:substr(self.start_of_packet + self.header_length, self.header_length + self.data_field_length)
end

--- Returns the whole content of the packet
-- @return a string of bytes
function Decom:get_packet()
    return self.buffer:substr(self.start_of_packet, self.header_length + self.data_field_length)
end

--- Decommutes and returns the values of the parameter inside the packet
-- using the decommutation function provided by the decommutation model.
-- @return an iterator over the parameter values
function Decom:iter_values()  
    assert(self.decommutation_fn, "Iterating on decommuted values requires that a decommutation model is provided at decom initialization")
    return self.decommutation_fn(self, self.start_of_packet * 8)    
end

-- Reads a CCSDS Space Packet Header at the current cursor position 
function Decom:has_more()        
    local block 

    -- next packet has already been read entirely so we know there is one
    if self.packet_length ~= 0 then
        return true
    end

    -- try to read a space packet header header      
    self.header_length = self:read_space_packet_header()        

    -- if header_length is still 0 then there was not enough data 
    -- in the buffer to read a header, so there is obviously not 
    -- enough data for a whole packet
    if self.header_length == 0 then        
        return false
    end

    -- check that there is enough bytes in the buffer to the payload of the packet
    local packet_length = self.header_length + self.space_packet_header.length + 1
    if self.buffer:len() < self.start_of_packet + packet_length then
        return false        
    end    

    self.data_field_length = self.space_packet_header.length + 1
    self.packet_length = packet_length           

    return true    
end

--- Moves to the next packet in the internal buffer
-- Internal use only
function Decom:next()
    
    -- update statistics
    self.total_packets = self.total_packets + 1   
    local apid_count = self.apid_counts[self.space_packet_header.apid]
    self.apid_counts[self.space_packet_header.apid] = apid_count and apid_count + 1 or 1

    -- move read cursor forward 
    self.start_of_packet = self.start_of_packet + self.packet_length
    
    self:reset()
end

--- Reset the part of the decommutation state that concerns the current packet
-- Internal use only
function Decom:reset()
    -- reset packet lengths    
    self.header_length = 0
    self.secondary_header_length = 0
    self.packet_length = 0
end

--- Decommutes the parameter values and return a JSON object
-- @return a string with the paraeter values encoded as a JSON object
function Decom:to_json()
    local buf = Buffer()
    local first = true    
    buf:append_luastr_right("{")
    for name, raw_val, eng_val in decom:iter_values() do                
        local s = string.format('%s"%s": [%s, %q]', (not first and ', ') or '', name, raw_val, eng_val)
        buf:append_luastr_right(s)        
        first = false
    end
    buf:append_luastr_right("}\n") 
    return tostring(buffer)
end

--- Decommutes the parameter values and write a serialized JSON object to out
-- @out a file object to write to (defaults to io.stdout)
function Decom:write_json(out)
    out = out or io.stdout
    for name, raw_val, eng_val in decom:iter_values() do                    
        local s = string.format('%s"%s": [%s, %q]', (not first and ', ') or '', name, raw_val, eng_val)        
        first = false
    end
end

--- Outputs the internal statistics
-- @out a file object to write to (defaults to io.stdout)
function Decom:print_stats(out)    
    out = out or io.stdout    
    out:write ("PACKETS: " .. self.total_packets .. "\n")
    for key, value in pairs(self.apid_counts) do 
        out:write ("APID " .. key .. ": " .. value .. "\n")        
    end    
end

return Decom



