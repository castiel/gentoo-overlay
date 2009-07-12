--[[ $%BEGINLICENSE%$
 Copyright (C) 2007-2008 MySQL AB, 2008 Sun Microsystems, Inc

 This program is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; version 2 of the License.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

 $%ENDLICENSE%$ --]]

---
-- a flexible statement based load balancer with connection pooling
--
-- * build a connection pool of min_idle_connections for each backend and maintain
--   its size
-- * 
-- 
-- 

local commands    = require("proxy.commands")
local tokenizer   = require("proxy.tokenizer")
local lb          = require("proxy.balance")
local auto_config = require("proxy.auto-config")

--- config
--
-- connection pool
if not proxy.global.config.rwsplit then
	proxy.global.config.rwsplit = {
		min_idle_connections = 2,
		max_idle_connections = 8,
		prefer_slave = true,
		default_ro = 0,
		is_debug = false
	}
end

---
-- read/write splitting sends all non-transactional SELECTs to the slaves
--
-- is_in_transaction tracks the state of the transactions
local is_in_transaction       = false

-- if this was a SELECT SQL_CALC_FOUND_ROWS ... stay on the same connections
local is_in_select_calc_found_rows = false


--- 
-- get a connection to a backend
--
-- as long as we don't have enough connections in the pool, create new connections
--
function connect_server() 
	local is_debug = proxy.global.config.rwsplit.is_debug
	local prefer_slave = proxy.global.config.rwsplit.prefer_slave
	-- make sure that we connect to each backend at least ones to 
	-- keep the connections to the servers alive
	--
	-- on read_query we can switch the backends again to another backend

	if is_debug then
		print()
		print("[connect_server] " .. proxy.connection.client.dst.name)
	end

	local rw_ndx = 0
	local ro_ndx = 0

	-- init all backends 
	for i = 1, #proxy.global.backends do
 		local s        = proxy.global.backends[i]
		local pool     = s.pool -- we don't have a username yet, try to find a connections which is idling
		local cur_idle = pool.users[""].cur_idle_connections

		pool.min_idle_connections = proxy.global.config.rwsplit.min_idle_connections
		pool.max_idle_connections = proxy.global.config.rwsplit.max_idle_connections
		
		if is_debug then
			print("  [".. i .."].dst.name           = " .. s.dst.name);
			print("  [".. i .."].connected_clients = " .. s.connected_clients)
			print("  [".. i .."].pool.cur_idle     = " .. cur_idle)
			print("  [".. i .."].pool.max_idle     = " .. pool.max_idle_connections)
			print("  [".. i .."].pool.min_idle     = " .. pool.min_idle_connections)
			print("  [".. i .."].type = " .. s.type)
			print("  [".. i .."].state = " .. s.state)
		end

		-- prefer connections to the master 
		if s.type == proxy.BACKEND_TYPE_RW and
		   s.state ~= proxy.BACKEND_STATE_DOWN and
--		   (prefer_slave == false or s.state == proxy.BACKEND_STATE_UNKNOWN ) and
		   cur_idle < pool.min_idle_connections then
			proxy.connection.backend_ndx = i
			break
		elseif s.type == proxy.BACKEND_TYPE_RO and
		       s.state ~= proxy.BACKEND_STATE_DOWN and
		       cur_idle < pool.min_idle_connections then
			proxy.connection.backend_ndx = i
			break
		elseif s.type == proxy.BACKEND_TYPE_RW and
		       s.state ~= proxy.BACKEND_STATE_DOWN and
		       rw_ndx == 0 then
			rw_ndx = i
		elseif s.type == proxy.BACKEND_TYPE_RO and
		       s.state ~= proxy.BACKEND_STATE_DOWN and
		       ro_ndx == 0 then
			ro_ndx = i
			proxy.global.config.rwsplit.default_ro = ro_ndx
		end
	end
	if is_debug then
		print("  [" .. proxy.connection.backend_ndx .. "] is SELECTED")
	end
	if proxy.connection.backend_ndx == 0 then
		-- we take the first slave in forced slave mode when we have at least one rw connection up.
		if prefer_slave == true and 
			proxy.global.backend[rw_ndx].state == BACKEND_STATE_UP then
			if is_debug then
				print("  [" .. ro_ndx .. "] taking slave as default")
			end
			proxy.connection.backend_ndx = ro_ndx
		else
			if is_debug then
				print("  [" .. rw_ndx .. "] taking master as default")
			end
			proxy.connection.backend_ndx = rw_ndx
		end
	end

	-- pick a random backend
	--
	-- we someone have to skip DOWN backends

	-- ok, did we got a backend ?

	if proxy.connection.server then 
		if is_debug then
			print("  using pooled connection from: " .. proxy.connection.backend_ndx)
		end

		-- stay with it
		return proxy.PROXY_IGNORE_RESULT
	end

	if is_debug then
		print("  [" .. proxy.connection.backend_ndx .. "] idle-conns below min-idle")
	end

	-- open a new connection 
end

--- 
-- put the successfully authed connection into the connection pool
--
-- @param auth the context information for the auth
--
-- auth.packet is the packet
function read_auth_result( auth )
	
	local is_debug = proxy.global.config.rwsplit.is_debug
	
	if is_debug then
		print("[read_auth_result] " .. proxy.connection.client.dst.name)
	end
	if auth.packet:byte() == proxy.MYSQLD_PACKET_OK then
		-- auth was fine, disconnect from the server
		proxy.connection.backend_ndx = 0
	elseif auth.packet:byte() == proxy.MYSQLD_PACKET_EOF then
		-- we received either a 
		-- 
		-- * MYSQLD_PACKET_ERR and the auth failed or
		-- * MYSQLD_PACKET_EOF which means a OLD PASSWORD (4.0) was sent
		if is_debug then
			print("(read_auth_result) ... not ok yet");
		end
	elseif auth.packet:byte() == proxy.MYSQLD_PACKET_ERR then
		-- auth failed
	end
end

function myidle_ro() 
	local max_conns = -1
	local max_conns_ndx = 0
	local is_debug = proxy.global.config.rwsplit.is_debug

	for i = 1, #proxy.global.backends do
		local s = proxy.global.backends[i]
		local conns = s.pool.users[proxy.connection.client.username]
		
		local pool     = s.pool -- we don't have a username yet, try to find a connections which is idling
		local cur_idle = pool.users[proxy.connection.client.username].cur_idle_connections

		if is_debug then
			print("  ");
			print("  [".. i .."].dst.name           = " .. s.dst.name);
			print("  [".. i .."].connected_clients = " .. s.connected_clients)
			print("  [".. i .."].pool.cur_idle     = " .. cur_idle)
			print("  [".. i .."].pool.max_idle     = " .. pool.max_idle_connections)
			print("  [".. i .."].pool.min_idle     = " .. pool.min_idle_connections)
			print("  [".. i .."].type = " .. s.type)
			print("  [".. i .."].state = " .. s.state)
		end

		-- pick a slave which has some idling connections
		if s.type == proxy.BACKEND_TYPE_RO and 
		   s.state == proxy.BACKEND_STATE_UP then
--		   conns.cur_idle_connections > 0 then
			if max_conns == -1 or 
			   s.connected_clients < max_conns then
				max_conns = s.connected_clients
				max_conns_ndx = i
			end
		end
	end

	return max_conns_ndx
end

--- 
-- read/write splitting
function read_query( packet )
	local is_debug = proxy.global.config.rwsplit.is_debug
	local cmd      = commands.parse(packet)
	local c        = proxy.connection.client
	local prefer_slave = proxy.global.config.rwsplit.prefer_slave

	local r = auto_config.handle(cmd)
	if r then return r end

	local tokens
	local norm_query

	-- looks like we have to forward this statement to a backend
	if is_debug then
		print("[read_query] " .. proxy.connection.client.dst.name)
		print("  current backend   = " .. proxy.connection.backend_ndx)
		print("  client default db = " .. c.default_db)
		print("  client username   = " .. c.username)
		if cmd.type == proxy.COM_QUERY then 
			print("  query             = "        .. cmd.query)
		end
	end

	if cmd.type == proxy.COM_QUIT then
		-- don't send COM_QUIT to the backend. We manage the connection
		-- in all aspects.
		proxy.response = {
			type = proxy.MYSQLD_PACKET_OK,
		}
	
		if is_debug then
			print("  (QUIT) current backend   = " .. proxy.connection.backend_ndx)
		end

		return proxy.PROXY_SEND_RESULT
	end

	proxy.queries:append(1, packet,{resultset_is_needed = true})

	-- read/write splitting 
	--
	-- send all non-transactional SELECTs to a slave
	if cmd.query and is_debug then
		print("   send all non-transactional SELECTs to a slave".. cmd.query)
	end
	
	if not is_in_transaction and
	   cmd.type == proxy.COM_QUERY then
		tokens     = tokens or assert(tokenizer.tokenize(cmd.query))
		local stmt = tokenizer.first_stmt_token(tokens)
		
		if is_debug then
			print("   yes, normal query"..stmt.token_name)
		end
		
		if stmt.token_name == "TK_SQL_SELECT" or stmt.token_name == "TK_SQL_SHOW" then
			
			is_in_select_calc_found_rows = false
			local is_insert_id = false

			for i = 1, #tokens do
				local token = tokens[i]
				-- SQL_CALC_FOUND_ROWS + FOUND_ROWS() have to be executed 
				-- on the same connection
				-- print("token: " .. token.token_name)
				-- print("  val: " .. token.text)
				
				if not is_in_select_calc_found_rows and token.token_name == "TK_SQL_SQL_CALC_FOUND_ROWS" then
					is_in_select_calc_found_rows = true
				elseif not is_insert_id and (token.token_name == "TK_LITERAL" or token.token_name == "TK_FUNCTION") then
					local utext = token.text:upper()

					if utext == "LAST_INSERT_ID" or
					   utext == "@@INSERT_ID" then
						is_insert_id = true
					end
				end

				-- we found the two special token, we can't find more
				if is_insert_id and is_in_select_calc_found_rows then
					-- print("  >>>>>>> if is_insert_id and is_in_select_calc_found_rows then ")
					break
				end
			end

			-- if we ask for the last-insert-id we have to ask it on the original 
			-- connection
			--print("  not is_insert_id ")
			if not is_insert_id then
				local backend_ndx = myidle_ro()
				--print("  myidle_ro() " .. backend_ndx)
				if backend_ndx > 0 then
					--print("  if backend_ndx > 0 then ")
					proxy.connection.backend_ndx = backend_ndx
				end
			else
				--print("   found a SELECT LAST_INSERT_ID(), staying on the same backend")
			end
			--print("   Backend: " .. proxy.connection.backend_ndx)
		else 
			local backend_ndx = 0
			for i = 1, #proxy.global.backends do
				local s = proxy.global.backends[i]
				local conns = s.pool.users[proxy.connection.client.username]
				if conns.cur_idle_connections > 0 and 
				s.state ~= proxy.BACKEND_STATE_DOWN and 
				s.type == proxy.BACKEND_TYPE_RW then
					backend_ndx = i
					break
				elseif s.type == proxy.BACKEND_TYPE_RW then
				-- notice no break, should grab some other master if possible
					backend_ndx = i
				end
			end
			proxy.connection.backend_ndx = backend_ndx
			if is_debug then
				print("   ---> WRITE query, using: " .. proxy.connection.backend_ndx)
			end
		end
	end

	-- no backend selected yet, pick a master
	if proxy.connection.backend_ndx == 0 then
		if prefer_slave == true then
			proxy.connection.backend_ndx = lb.idle_ro()
			if proxy.connection.backend_ndx == 0 then
				proxy.connection.backend_ndx = lb.idle_failsafe_rw()
			end
		else 
			-- we don't have a backend right now
			-- 
			-- let's pick a master as a good default
			--
			proxy.connection.backend_ndx = lb.idle_failsafe_rw()
		end
	end

	-- by now we should have a backend
	--
	-- in case the master is down, we have to close the client connections
	-- otherwise we can go on
	if proxy.connection.backend_ndx == 0 then
		return proxy.PROXY_SEND_QUERY
	end

	local s = proxy.connection.server

	-- if client and server db don't match, adjust the server-side 
	--
	-- skip it if we send a INIT_DB anyway
	if cmd.type ~= proxy.COM_INIT_DB and 
	   c.default_db and c.default_db ~= s.default_db then
	   	if is_debug then
			print("    server default db: " .. s.default_db)
			print("    client default db: " .. c.default_db)
			print("    syncronizing")
		end
		proxy.queries:prepend(2, string.char(proxy.COM_INIT_DB) .. c.default_db)
	end

	-- send to master
	if is_debug then
		if proxy.connection.backend_ndx > 0 then
			local b = proxy.global.backends[proxy.connection.backend_ndx]
			if is_debug then
				print("  sending to " .. proxy.connection.backend_ndx .."backend : " .. b.dst.name);
				print("    is_slave         : " .. tostring(b.type == proxy.BACKEND_TYPE_RO));
				print("    server default db: " .. s.default_db)
				print("    server username  : " .. s.username)
			end
		end
		if is_debug then
			print("    in_trans        : " .. tostring(is_in_transaction))
			print("    in_calc_found   : " .. tostring(is_in_select_calc_found_rows))
			print("    COM_QUERY       : " .. tostring(cmd.type == proxy.COM_QUERY))
		end
	end

	return proxy.PROXY_SEND_QUERY
end

---
-- as long as we are in a transaction keep the connection
-- otherwise release it so another client can use it
function read_query_result( inj ) 
	local is_debug = proxy.global.config.rwsplit.is_debug
	local res      = assert(inj.resultset)
  	local flags    = res.flags

--	if inj.id ~= 1 then
		--print("    INJ 1 " ..inj.id)
		-- ignore the result of the USE <default_db>
		-- the DB might not exist on the backend, what do do ?
		--
		if inj.id == 2 then
			--print("    INJ 2 " ..inj.id)
			-- the injected INIT_DB failed as the slave doesn't have this DB
			-- or doesn't have permissions to read from it
			if res.query_status == proxy.MYSQLD_PACKET_ERR then
				--print("    INJ reset " ..inj.id)
				proxy.queries:reset()

				proxy.response = {
					type = proxy.MYSQLD_PACKET_ERR,
					errmsg = "can't change DB ".. proxy.connection.client.default_db ..
						" to on slave " .. proxy.global.backends[proxy.connection.backend_ndx].dst.name
				}

				return proxy.PROXY_SEND_RESULT
			end
		end
--		print("    INJ  proxy.PROXY_IGNORE_RESULT " ..inj.id)
--		return proxy.PROXY_IGNORE_RESULT
--	end

	is_in_transaction = flags.in_trans
	local have_last_insert_id = (res.insert_id and (res.insert_id > 0))

	if not is_in_transaction and 
	   not is_in_select_calc_found_rows and
	   not have_last_insert_id then
		-- release the backend
--		proxy.connection.backend_ndx = 0
	elseif is_debug then
		print("(read_query_result) staying on the same backend")
		print("    in_trans        : " .. tostring(is_in_transaction))
		print("    in_calc_found   : " .. tostring(is_in_select_calc_found_rows))
		print("    have_insert_id  : " .. tostring(have_last_insert_id))
	end
end

--- 
-- close the connections if we have enough connections in the pool
--
-- @return nil - close connection 
--         IGNORE_RESULT - store connection in the pool
function disconnect_client()
	local is_debug = proxy.global.config.rwsplit.is_debug
	if is_debug then
		print("[disconnect_client] " .. proxy.connection.client.dst.name)
	end

	-- make sure we are disconnection from the connection
	-- to move the connection into the pool
	proxy.connection.backend_ndx = 0
end

