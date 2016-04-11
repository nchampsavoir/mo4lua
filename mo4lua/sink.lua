local zmq      = require "lzmq"

local context = zmq.init(1)

local sub = context:socket(zmq.SUB)
sub:set_subscribe("")
sub:bind("tcp://*:6677")

total = 0
count = 0

while true do
    header, body = sub:recvx()   
    total = total + header:len() + body:len()
    count = count + 1
    if count % 40000 == 0 then
        print(string.format("%d bytes received", total))
    end
end

context:term()