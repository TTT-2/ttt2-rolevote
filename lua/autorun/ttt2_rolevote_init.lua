RoleVote = {}
RoleVote.Config = {}

--Default Config
MapVoteConfigDefault = {
	RoleLimit = 24,
	TimeLimit = 28,
	RolesBeforeRevote = 3,
	RTVPlayerCount = 3
}
--Default Config

function RoleVote.HasExtraVotePower(ply)
	-- Example that gives admins more voting power
	--[[
    if ply:IsAdmin() then
		return true
	end
    ]]

	return false
end


RoleVote.Votes = {}
RoleVote.Allow = false

RoleVote.UPDATE_VOTE = 1
RoleVote.UPDATE_WIN = 3

if SERVER then
	AddCSLuaFile()
	AddCSLuaFile("rolevote/cl_init.lua")

	include("rolevote/init.lua")
else
	include("rolevote/cl_init.lua")
end
