local zmq      = require "lzmq"
local argparse = require "3rdparty.argparse"

local parser = argparse("acqctl", "Command line interface to control the acquisition daemon")
parser:option("-p --acqd-port", "Acqd control port number", "6666")
parser:command("go")

local args = parser:parse()
local context = zmq.init(1)

--  Control socket
local acqd = context:socket(zmq.PUSH)
local url = string.format("tcp://localhost:%s", args.acqd_port)
acqd:connect(url)
assert(acqd)

if args.go then
    acqd:send("GO")
end

context:term()