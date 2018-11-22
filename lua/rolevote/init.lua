include("ttt2rtv.lua")

util.AddNetworkString("TTT2RoleVoteStart")
util.AddNetworkString("TTT2RoleVoteUpdate")
util.AddNetworkString("TTT2RoleVoteCancel")
util.AddNetworkString("TTT2RTV_Delay")

local rolevote_enabled = CreateConVar("ttt2_rolevote_enabled", "1", {FCVAR_NOTIFY, FCVAR_ARCHIVE})
local lastrole = CreateConVar("ttt2_rolevote_lastrole", "0", {FCVAR_ARCHIVE})

hook.Add("TTTUlxInitRWCVar", "TTT2RoleVoteInitRWCVar", function(name)
	ULib.replicatedWritableCvar("ttt2_rolevote_enabled", "rep_ttt2_rolevote_enabled", rolevote_enabled:GetInt(), true, false, name)
end)

RoleVote.Continued = false

function RoleVote.EndTimer()
	RoleVote.Allow = false

	local role_results = {}
	local plys = player.GetAll()

	for k, v in pairs(RoleVote.Votes) do
		if not role_results[v] then
			role_results[v] = 0
		end

		for _, v2 in ipairs(plys) do
			if v2:SteamID64() == k then
				if RoleVote.HasExtraVotePower(v2) then
					role_results[v] = role_results[v] + 2
				else
					role_results[v] = role_results[v] + 1
				end
			end
		end
	end

	local winner = table.GetWinningKey(role_results) or 3

	-- random role
	if winner == 3 then
		for _, role in RandomPairs(GetRoles()) do
			if IsRoleSelectable(role, true) and role ~= INNOCENT and role ~= TRAITOR then
				winner = role.index

				break
			end
		end
	end

	RoleVote.DisabledRoles = {}

	RunConsoleCommand("ttt2_rolevote_lastrole", winner == 4 and "none" or GetRoleByIndex(winner).name)

	net.Start("TTT2RoleVoteUpdate")
	net.WriteUInt(RoleVote.UPDATE_WIN, 3)
	net.WriteUInt(winner, ROLE_BITS)
	net.Broadcast()

	hook.Run("TTT2RoleVoteWinner", winner)

	timer.Simple(3, function()
		hook.Run("RoleVoteChange", winner)

		if RoleVote.MapVote and MapVote and MapVote.Start then
			MapVote.Start(nil, nil, nil, nil)
		end
	end)
end

function RoleVote.Start(length, current, limit, prefix, mapvote)
	if not rolevote_enabled:GetBool() then return end

	length = length or RoleVote.Config.TimeLimit or 28
	limit = limit or RoleVote.Config.RoleLimit or 24 -- TODO ConVar

	local roles = GetRoles()
	local vote_roles = {}
	local vote_roles2 = {}
	local amt = 0
	local ply_count = 0

	for _, v in ipairs(player.GetAll()) do

		-- everyone on the spec team is in specmode
		if IsValid(v) and not v:GetForceSpec() then
			ply_count = ply_count + 1
		end
	end

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

	if #vote_roles < 1 then return end

	net.Start("TTT2RoleVoteStart")
	net.WriteUInt(amt, 32)

	for i = 1, amt do
		net.WriteUInt(vote_roles2[i], ROLE_BITS)
	end

	net.WriteUInt(length, 32)
	net.Broadcast()

	RoleVote.Allow = true
	RoleVote.CurrentRoles = vote_roles
	RoleVote.Votes = {}
	RoleVote.MapVote = mapvote

	timer.Create("TTT2RoleVote", length, 1, function()
		RoleVote.EndTimer()
	end)
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

net.Receive("TTT2RoleVoteUpdate", function(len, ply)
	if RoleVote.Allow and IsValid(ply) then
		local update_type = net.ReadUInt(3)

		if update_type == RoleVote.UPDATE_VOTE then
			local role = net.ReadUInt(ROLE_BITS)

			if table.HasValue(RoleVote.CurrentRoles, role) or role == 3 or role == 4 then
				RoleVote.Votes[ply:SteamID64()] = role

				net.Start("TTT2RoleVoteUpdate")
				net.WriteUInt(RoleVote.UPDATE_VOTE, 3)
				net.WriteEntity(ply)
				net.WriteUInt(role, ROLE_BITS)
				net.Broadcast()
			end
		end
	end
end)

if file.Exists("RoleVote/config.txt", "DATA") then
	RoleVote.Config = util.JSONToTable(file.Read("RoleVote/config.txt", "DATA"))
else
	RoleVote.Config = {}
end

function RoleVote.Cancel()
	if RoleVote.Allow then
		RoleVote.Allow = false

		net.Start("TTT2RoleVoteCancel")
		net.Broadcast()

		timer.Remove("TTT2RoleVote")
	end
end
