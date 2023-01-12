--- File to be included in NetLogo Mutliagent Models
--- Communication for NetLogo Multiagent models
--- Includes primitives for message creation and handling in NetLogo 
--- Original Version for Netlogo 2 (2005) I. Sakellariou
--- Adapted to NetLogo 4 (2008) I. Sakellariou
--- Adapted to Lua (2020) Ll. Ribas-Xirgo

--- Requirements
--- All agents that are able to communicate WILL have an table incoming_queue.
--- This is the table to which all messages are recorded.
--- So, in your agent table there cannot be an item with this name.
--- MAKE SURE that you call ACL:setup(agent) before using communications in your agent.

----------------------------------------------------------------------------------------------
------- COMMUNICATION
----------------------------------------------------------------------------------------------
---- MESSAGE PROCESSING -------------------------------
------------------------------------------------------------------
-- Messages are tables with "sender", "receiver", fields
-- Each item is a list, possibly empty, of data
-- sender: table of the sender
-- receiver: table of objects with "incoming_queue" items
--

local ACL = {
  create_msg = function( s, r, p, c )
    local msg = {}
    msg.sender = s
    msg.receiver = {}
    msg.performative = "informative"
    msg.content = "empty"
    if r ~= nil then
      msg.receiver = r
      if p ~= nil then
        msg.performative = p
        if c ~= nil then
          msg.content = c
        end -- if
      end -- if
    end -- if
    return msg
  end -- create_msg
  ,
  setup = function( t )
    t.incoming_queue = {}
  end -- setup
  ,
  send = function( msg ) -- adds msg to receivers' incoming queues
    for i, r in ipairs( msg.receiver ) do
      if r.incoming_queue then 
        local copy = {}; for f in pairs( msg ) do copy[f] = msg[f] end
        table.insert( r.incoming_queue, copy )
        --print( "ACL.send:", msg.sender.__id, "->", r.__id, "=", msg.performative )
      end -- if
    end -- for
  end -- send
  ,
  receive = function( s ) -- takes a msg out of the incoming queue
    local msg = nil
    if s.incoming_queue and #s.incoming_queue>0 then
      msg = s.incoming_queue[1]
      table.remove( s.incoming_queue, 1 )
      --print( "ACL.receive:", msg.sender.__id, "->", msg.performative )
    end -- if
    return msg
  end -- receive
  ,
  get = receive
  ,
  pending = function( s )
    local size = 0
    if s.incoming_queue then
      size = #s.incoming_queue
    end -- if
    return size
  end -- pending
  ,
  first_msg = function( s ) -- returns the first message of incoming queue
    local msg = nil
    if s.incoming_queue and #s.incoming_queue>0 then
      msg = s.incoming_queue[1]
    end -- if
    return msg
  end -- first_msg
  ,   
  get_sender = function( msg )
    return msg.sender
  end -- get_sender
  ,
  get_performative = function( msg )
    return msg.performative
  end -- get_performative
  ,
  get_content = function( msg )
    return msg.content
  end -- get_content
  ,
  add_receiver = function( msg, r )
    table.insert( msg.receiver, r )
  end -- add_receiver
  ,
  add_multiple_receivers = function( msg, rlist )
    for i, r in ipairs(rlist) do
      table.insert( msg.receiver, r )
    end -- for
  end
} -- ACL

return ACL

