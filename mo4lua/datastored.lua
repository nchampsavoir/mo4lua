local zmq      = require "lzmq"
local argparse = require "3rdparty.argparse"
local Decom = require "libdecom"

local parser = argparse("datastored", "A storage daemon for packets and parameters in lua")
parser:option("-a --acqd-port", "Acquisition Daemon subscription port number")
parser:option("-d --decomd-port", "Decom Daemon subscription port number", "5559")
parser:option("-o --output", "Write JSON output to a file")
parser:flag("-v --verbose")

local args = parser:parse()
local context = zmq.init(1)

function printf(fmt, ...)
  return io.write((string.format(fmt, ...)))
end

--  Socket to receive packets from
local acqd
if args.acqd_port then
    acqd = context:socket(zmq.SUB)
    acqd:set_subscribe("")
    local url = string.format("tcp://localhost:%s", args.acqd_port)
    acqd:connect(url)
    assert(acqd)
    print('Subscribed to acqd at ' .. url)
end

--  Socket to receive packets from
local decomd
if args.decomd_port then
    decomd = context:socket(zmq.SUB)
    decomd:set_subscribe("")
    local url = string.format("tcp://localhost:%s", args.decomd_port)
    decomd:connect(url)
    assert(decomd)
    print('Subscribed to decomd at ' .. url)
end

local outputfile = nil
if args.output then
    outputfile, err = io.open(args.output, "w")
    if outputfile == nil then
        print(err)
        os.exit()
    end
end

local total_bytes = 0    
local start_time = 0
local receive_buffer = 0   
local total_packets = 0
local start_time = nil 
local verbose = args.verbose

if outputfile then outputfile:write("[\n") end

--  Process tasks forever
while true do   
    
    local msg = decomd:recv()   
    if not start_time then
        start_time = os.clock()
    end
    if verbose and total_packets % 100000 == 0 then print('Packets received: ' .. total_packets) end
    
    if string.sub(msg, 1, 3) == "END" then break end
    total_packets = total_packets + 1
    total_bytes = total_bytes + string.len(msg)           
    if outputfile then outputfile:write(msg) end    
end

if outputfile then outputfile:write("]\n") end

local end_time = os.clock()
local elapsed_time = end_time-start_time

if acqd then acqd:close() end
if decomd then decomd:close() end

print ("Packets: " .. total_packets)
print ("Bytes: " .. math.floor(total_bytes / 1000) .. " KB")
print ("Time: " .. string.format("%.2f s", elapsed_time))
print ("Speed: " .. math.floor(total_bytes / elapsed_time / 1000) .. " KB/s")

context:term()