local zmq      = require "lzmq"
local argparse = require "3rdparty.argparse"
local Decom = require "libdecom"

local parser = argparse("acqd", "A telemetry acquisition daemon in lua")
parser:argument("inputfile")
parser:option("-c --control-port", "Control port number", "6666")
parser:option("-p --publish-port", "Pubclish port number", "6667")
parser:flag("-v --verbose")


local args = parser:parse()
local context = zmq.init(1)

function printf(fmt, ...)
  return io.write((string.format(fmt, ...)))
end

local file, err = io.open(args.inputfile, "rb")
if file == nil then
    print(err)
    os.exit(1)
end

local decom = Decom()

--  Control socket
local control = context:socket(zmq.PULL)
local url = string.format("tcp://*:%s", args.control_port)
control:bind(url)
print('Listening on ' .. url .. ' ...')

--  Publish socket
local pub = context:socket(zmq.PUB)
pub:bind(string.format("tcp://*:%s", args.publish_port))


local start_time = nil 
local total_bytes = 0
local total_credit = 0

local block_size = 2^15
local verbose = args.verbose

while true do
    msg = control:recv()   
    if msg == "CREDIT" then 
        total_credit = total_credit + 200 
    elseif msg == "GO" then
        break
    else
        print("Wrong control message " .. msg)
    end
end

print('Processing file ' .. args.inputfile .. ' ...')

while true do
    block = file:read(block_size)    
    if block == nil then
        break -- EOF
    end

    -- push block at the end of the decom buffer
    decom:append(block)

    -- while there are still packets to be read in the decom buffer
    while decom:has_more() do

        -- if packet is invalid, bail out
        if not decom:packet_is_valid() then
            print ("OUPS")
            os.exit(1)
        end

        -- ensure that we still have credit to send new packets
        if total_credit == 0 then
            -- if not, wait for new credit
            if verbose then print('Waiting for credit...') end
            control:recv()      
            if not start_time then
                start_time = os.clock()
            end
            total_credit = 200
            if verbose then print('Credit received.') end
        end        

        -- get the content of the packet from the decom buffer
        local packet_data = decom:get_packet()

        -- send the content of the packet over the pub socket
        if verbose then print('Sending packet ...') end
        pub:send(packet_data)
        
        -- update stats and credits
        total_bytes = total_bytes + string.len(packet_data)
        total_credit = total_credit - 1

        -- move to the next packet
        decom:next()
    end
end

pub:send("")
pub:close(-1)
control:close(-1)
file:close()

local end_time = os.clock()
local elapsed_time = end_time-start_time

decom:print_stats()

print ("----------------------------")
print ("Bytes: " .. math.floor(total_bytes / 1000) .. " KB")
print ("Time: " .. string.format("%.2f s", elapsed_time))
print ("Speed: " .. math.floor(total_bytes / elapsed_time / 1000) .. " KB/s")

context:term()