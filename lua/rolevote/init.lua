include("ttt2rtv.lua")

util.AddNetworkString("TTT2RoleVoteStart")
util.AddNetworkString("TTT2RoleVoteUpdate")
util.AddNetworkString("TTT2RoleVoteCancel")
util.AddNetworkString("TTT2RTV_Delay")

local rolevote_enabled = CreateConVar("ttt2_rolevote_enabled", "1", {FCVAR_NOTIFY, FCVAR_ARCHIVE})

hook.Add("TTTUlxInitRWCVar", "TTT2RoleVoteInitRWCVar", function(name)
	ULib.replicatedWritableCvar("ttt2_rolevote_enabled", "rep_ttt2_rolevote_enabled", rolevote_enabled:GetInt(), true, false, name)
end)

RoleVote.Continued = false

function RoleVote.Start(length, current, limit, prefix, fn)
	if not rolevote_enabled:GetBool() then return end

	length = length or RoleVote.Config.TimeLimit or 28
	limit = limit or RoleVote.Config.RoleLimit or 24 -- TODO ConVar

	RoleVote.MapVoteFN = fn

	local roles = GetRoles()
	local vote_roles = {}
	local amt = 0

	for _, role in RandomPairs(roles) do
		if IsRoleSelectable(role, true) and role ~= INNOCENT and role ~= TRAITOR then
			vote_roles[#vote_roles + 1] = role.index
			amt = amt + 1

			if limit and amt >= limit then break end
		end
	end

	if amt < 1 then return end

	net.Start("TTT2RoleVoteStart")
	net.WriteUInt(#vote_roles, 32)

	for i = 1, #vote_roles do
		net.WriteUInt(vote_roles[i], ROLE_BITS)
	end

	net.WriteUInt(length, 32)
	net.Broadcast()

	RoleVote.Allow = true
	RoleVote.CurrentRoles = vote_roles
	RoleVote.Votes = {}

	timer.Create("TTT2RoleVote", length, 1, function()
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

		local winner = table.GetWinningKey(role_results) or 1

		RoleVote.DisabledRoles = {}
		RoleVote.Winner = winner

		net.Start("TTT2RoleVoteUpdate")
		net.WriteUInt(RoleVote.UPDATE_WIN, 3)
		net.WriteUInt(winner, ROLE_BITS)
		net.Broadcast()

		timer.Simple(4, function()
			hook.Run("RoleVoteChange", winner)

			if RoleVote.MapVoteFN then
				RoleVote.MapVoteFN()
			end
		end)
	end)
end

hook.Add("TTT2RoleNotSelectable", "TTT2RoleVoteModifyRoleSelect", function(roleData)
	if rolevote_enabled:GetBool() and RoleVote.Winner then
		local rd = GetRoleByIndex(RoleVote.Winner)

		if rd and rd ~= roleData then
			return true
		end
	end
end)

net.Receive("TTT2RoleVoteUpdate", function(len, ply)
	if RoleVote.Allow and IsValid(ply) then
		local update_type = net.ReadUInt(3)

		if update_type == RoleVote.UPDATE_VOTE then
			local role = net.ReadUInt(ROLE_BITS)

			if table.HasValue(RoleVote.CurrentRoles, role) then
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
