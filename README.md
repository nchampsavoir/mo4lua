**WARNING: THIS PROJECT IS DEPRECATED. PLEASE GO TO https://github.com/nchampsavoir/xtceproc FOR STREAMLINED VERSION OF MY LUAJIT-BASED DECOMMUTATION ENGINE**

mo4lua
======

Spacecraft Monitoring and Control for LuaJIT

Overview
--------

This is an attempt at developping a set of tools for telemetry and telecommand processing in LuaJIT, centered around the CCSDS Mission Operations set of standards, namely XTCE and the MO Stack (MAL, COM, M&C services). 

Also there are no tests.

Also it's awesome: the decommutation library can process 50Mb of raw telemetry in less than 15 seconds on my MacBook Air. 

Content
-------

This repo consists of decommutation library for LuaJIT in `libdecom.lua` (with various included dependencies) and a set of scripts:

 - **decom**: A command line interface to the decom library. Takes a file and an optional decommutation model and outputs the results of the decommutation in the form of serialized JSON objects in a file. 
 - **generator**: Generates a Lua decommutation model from an *XTCE* file.
 - **concat**: Makes a big file by concatenating multiple copies of a small file 
 - **acqd**: A telemetry acquisition daemon in Lua. Reads packets from a file and send them one by one over a ZeroMQ socket
 - **acqctl**: command line interface to the acquisition deamon. Can only send a "go" command for now.
 - **decomd**: A telemetry decommutation daemon in Lua. Gets packets from an acquisition daemon and publish parameter values in JSON or MessagePack over a ZeroMQ socket.
 - **decomd**: A storage daemon for packets and parameters in Lua. Subscribe to parameter values from *decomd* and stores them in a file.

How stable is it?
-----------------

It's all very much a work in progress. i will break code and change APIs without warning. Do not use this software for anything serious (yet). I mean it. You've been warned.

Requirements
------------

The decommutation library requires LuaJIT 2.1+ as it relies on 64 bits bitop operations.

Documentation
-------------

There isn't any. But you can call the scripts with '--help' to get the basic options. For the rest, just look at the code.

License
-------

MIT

Contributing
------------

All contributions are welcome, especially pull requests (as long as the code is compatible with the MIT license).


