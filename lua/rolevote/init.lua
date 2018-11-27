include("ttt2rtv.lua")

util.AddNetworkString("TTT2RoleVoteStart")
util.AddNetworkString("TTT2RoleVoteUpdate")
util.AddNetworkString("TTT2RoleVoteCancel")
util.AddNetworkString("TTT2RTV_Delay")

local rolevote_enabled = CreateConVar("ttt2_rolevote_enabled", "1", {FCVAR_NOTIFY, FCVAR_ARCHIVE})
local rolevote_votes = CreateConVar("ttt2_rolevote_votes", "1", {FCVAR_NOTIFY, FCVAR_ARCHIVE})
local lastrole = CreateConVar("ttt2_rolevote_lastrole", "0", {FCVAR_ARCHIVE})

hook.Add("TTTUlxInitRWCVar", "TTT2RoleVoteInitRWCVar", function(name)
	ULib.replicatedWritableCvar("ttt2_rolevote_enabled", "rep_ttt2_rolevote_enabled", rolevote_enabled:GetInt(), true, false, name)
	ULib.replicatedWritableCvar("ttt2_rolevote_votes", "rep_ttt2_rolevote_votes", rolevote_votes:GetInt(), true, false, name)
end)

RoleVote.Continued = false

function RoleVote.EndTimer(mapchange)
	RoleVote.Allow = false

	local role_results = {}

	for ply, votes in pairs(RoleVote.Votes) do
		if IsValid(ply) then
			local votePower = RoleVote.HasExtraVotePower(ply)

			for _, v in ipairs(votes) do
				if votePower then
					role_results[v] = (role_results[v] or 0) + 2
				else
					role_results[v] = (role_results[v] or 0) + 1
				end
			end
		end
	end

	RoleVote.DisabledRoles = {}

	local winners = {}
	local sorted = {}
	local results = 0

	for k, v in pairs(role_results) do
		if not v then
			table.remove(role_results, k)
		else
			results = results + 1
		end
	end

	if results > 0 then
		table.sort(role_results, function(a, b)
			return a > b
		end)

		local count = 0

		for role, amount in pairs(role_results) do
			sorted[#sorted + 1] = role
			count = count + 1

			if count == RoleVote.MaxVotes then break end
		end
	end

	for i = 1, RoleVote.MaxVotes do
		local winner = sorted[i] or 3

		-- random role
		if winner == 3 then
			for _, role in RandomPairs(GetRoles()) do
				if IsRoleSelectable(role, true) and role ~= INNOCENT and role ~= TRAITOR then
					winner = role.index

					break
				end
			end
		end

		if winner == 4 then
			if #winners == 0 then -- none is #1 winner, don't select other roles
				winners[1] = winner

				break
			else
				continue
			end
		end

		winners[#winners + 1] = winner
	end

	SetLastRoles(winners)

	net.Start("TTT2RoleVoteUpdate")
	net.WriteUInt(RoleVote.UPDATE_WIN, 3)
	net.WriteUInt(#winners, ROLE_BITS)

	for i = 1, #winners do
		net.WriteUInt(winners[i], ROLE_BITS)
	end

	net.Broadcast()

	hook.Run("TTT2RoleVoteWinners", winners)

	timer.Simple(3, function()
		hook.Run("RoleVoteChange", winners)

		if mapchange then
			if MapVote and MapVote.Start then
				MapVote.Start(nil, nil, nil, nil)
			else
				timer.Simple(0, game.LoadNextMap)
			end
		end
	end)
end

function RoleVote.Start(length, current, limit, prefix, mapchange)
	if not rolevote_enabled:GetBool() then
		if mapchange then
			if MapVote and MapVote.Start then
				MapVote.Start(nil, nil, nil, nil)
			else
				timer.Simple(15, game.LoadNextMap)
			end
		end

		return
	end

	length = length or RoleVote.Config.TimeLimit or 28
	limit = limit or RoleVote.Config.RoleLimit or 24 -- TODO ConVar

	local roles = GetRoles()
	local vote_roles = {}
	local vote_roles2 = {}
	local amt = 0

	RoleVote.Voter = {}

	for _, v in ipairs(player.GetAll()) do
		-- everyone on the spec team is in specmode
		if IsValid(v) and not v:GetForceSpec() then -- and not v:IsBot()
			RoleVote.Voter[#RoleVote.Voter + 1] = v
		end
	end

	local ply_count = #RoleVote.Voter

	for _, role in RandomPairs(roles) do
		if role ~= INNOCENT and role ~= TRAITOR and IsRoleSelectable(role, true) then
			local tmp = GetConVar("ttt_" .. role.name .. "_min_players"):GetInt()

			vote_roles2[#vote_roles2 + 1] = role.index
			amt = amt + 1

			if ply_count >= tmp then
				vote_roles[#vote_roles + 1] = role.index
			end

			if limit and amt + 2 >= limit then break end -- +2 bcus of none and random option
		end
	end

	if #vote_roles < 1 then
		if mapchange then
			if MapVote and MapVote.Start then
				MapVote.Start(nil, nil, nil, nil)
			else
				timer.Simple(15, game.LoadNextMap)
			end
		end

		return
	end

	RoleVote.MaxVotes = rolevote_votes:GetInt()

	if RoleVote.MaxVotes > #vote_roles then
		RoleVote.MaxVotes = #vote_roles
	end

	net.Start("TTT2RoleVoteStart")
	net.WriteUInt(amt, ROLE_BITS)

	for i = 1, amt do
		net.WriteUInt(vote_roles2[i], ROLE_BITS)
	end

	net.WriteUInt(length, 32)
	net.WriteUInt(RoleVote.MaxVotes, ROLE_BITS)
	net.Broadcast()

	RoleVote.Allow = true
	RoleVote.CurrentRoles = vote_roles
	RoleVote.Votes = {}

	timer.Create("TTT2RoleVote", length, 1, function()
		RoleVote.EndTimer(mapchange)
	end)
end

net.Receive("TTT2RoleVoteUpdate", function(len, ply)
	if RoleVote.Allow and IsValid(ply) then
		local update_type = net.ReadUInt(3)

		if update_type == RoleVote.UPDATE_VOTE then
			local role = net.ReadUInt(ROLE_BITS)

			if table.HasValue(RoleVote.CurrentRoles, role) or role == 3 or role == 4 or role == 5 then
				if role ~= 5 then
					if RoleVote.MaxVotes == 1 then
						RoleVote.Votes[ply] = {role}
					else
						RoleVote.Votes[ply] = RoleVote.Votes[ply] or {}

						-- dont vote NONE if there are other roles already selected
						if role == 4 and #RoleVote.Votes[ply] > 1 then return end

						-- dont vote other roles if none is selected
						if role ~= 4 and RoleVote.Votes[ply][1] == 4 then return end

						local key

						for k, v in ipairs(RoleVote.Votes[ply]) do
							if v == role then
								key = k

								break
							end
						end

						if not key then
							RoleVote.Votes[ply][#RoleVote.Votes[ply] + 1] = role
						else
							table.remove(RoleVote.Votes[ply], key)
						end
					end
				else
					RoleVote.Votes[ply] = nil
				end

				net.Start("TTT2RoleVoteUpdate")
				net.WriteUInt(RoleVote.UPDATE_VOTE, 3)
				net.WriteEntity(ply)
				net.WriteUInt(role, ROLE_BITS)
				net.Broadcast()
			end
		end
	end
end)

function RoleVote.Cancel()
	if RoleVote.Allow then
		RoleVote.Allow = false

		net.Start("TTT2RoleVoteCancel")
		net.Broadcast()

		timer.Remove("TTT2RoleVote")
	end
end

hook.Add("TTT2RoleNotSelectable", "TTT2RoleVoteModifyRoleSelect", function(roleData)
	if rolevote_enabled:GetBool() then
		local lastRoleIndex = lastrole:GetString()

		if lastRoleIndex == "0" then
			lastRoleIndex = nil
		elseif lastRoleIndex == "none" then
			lastRoleIndex = 4
		else
			lastRoleIndex = GetRoleByName(lastRoleIndex).index

			if lastRoleIndex == ROLE_INNOCENT or lastRoleIndex == ROLE_TRAITOR then
				lastRoleIndex = nil
			end
		end

		if lastRoleIndex then
			if lastRoleIndex == 4 then
				return true
			end

			if lastRoleIndex ~= roleData.index then
				return true
			end
		end
	end
end)

function GetLastRoles()
	local unpacked = {}

	for _, roleName in ipairs(string.Explode(",", lastrole:GetString())) do
		unpacked[#unpacked + 1] = roleName == "none" and 4 or GetRoleByName(roleName).index
	end

	return unpacked
end

function SetLastRoles(lastroles)
	local packed = ""

	for k, role in ipairs(lastroles) do
		if k ~= 1 then
			packed = packed .. ","
		end

		packed = packed .. (role == 4 and "none" or GetRoleByIndex(role).name)
	end

	RunConsoleCommand("ttt2_rolevote_lastrole", packed)
end

if file.Exists("RoleVote/config.txt", "DATA") then
	RoleVote.Config = util.JSONToTable(file.Read("RoleVote/config.txt", "DATA"))
else
	RoleVote.Config = {}
end
