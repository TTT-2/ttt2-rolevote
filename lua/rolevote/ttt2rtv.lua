TTT2RTV = TTT2RTV or {}
TTT2RTV.TotalVotes = 0
TTT2RTV.Wait = 60 -- The wait time in seconds. This is how long a player has to wait before voting when the map changes.
TTT2RTV._ActualWait = CurTime() + TTT2RTV.Wait
TTT2RTV.PlayerCount = RoleVote.Config.TTT2RTVPlayerCount or 3
TTT2RTV.ChatCommands = {
	"!TTT2RTV",
	"/TTT2RTV",
	"TTT2RTV"
}

function TTT2RTV.ShouldChange()
	return TTT2RTV.TotalVotes >= math.Round(#player.GetAll() * 0.66)
end

function TTT2RTV.RemoveVote()
	TTT2RTV.TotalVotes = math.Clamp(TTT2RTV.TotalVotes - 1, 0, math.huge)
end

function TTT2RTV.Start()
	if TTT2 then
		net.Start("TTT2RTV_Delay")
		net.Broadcast()

		hook.Add("TTTEndRound", "RolevoteDelayed", function()
			RoleVote.Start(nil, nil, nil, nil)
		end)
	end
end


function TTT2RTV.AddVote(ply)
	if TTT2RTV.CanVote(ply) then
		TTT2RTV.TotalVotes = TTT2RTV.TotalVotes + 1
		ply.TTT2RTVoted = true

		MsgN(ply:Nick() .. " has voted to Rock the Vote.")
		PrintMessage(HUD_PRINTTALK, ply:Nick() .. " has voted to Rock the Vote. (" .. TTT2RTV.TotalVotes .. "/" .. math.Round(#player.GetAll() * 0.66) .. ")")

		if TTT2RTV.ShouldChange() then
			TTT2RTV.Start()
		end
	end
end

hook.Add("PlayerDisconnected", "RemoveTTT2RTV", function(ply)
	if ply.TTT2RTVoted then
		TTT2RTV.RemoveVote()
	end

	timer.Simple(0.1, function()
		if TTT2RTV.ShouldChange() then
			TTT2RTV.Start()
		end
	end)
end)

function TTT2RTV.CanVote(ply)
	local plyCount = #player.GetAll()

	if TTT2RTV._ActualWait >= CurTime() then
		return false, "You must wait a bit before voting!"
	end

	if GetGlobalBool("In_Voting") then
		return false, "There is currently a vote in progress!"
	end

	if ply.TTT2RTVoted then
		return false, "You have already voted to Rock the Vote!"
	end

	if TTT2RTV.ChangingRoles then
		return false, "There has already been a vote, the roles are going to change!"
	end

	if plyCount < TTT2RTV.PlayerCount then
		return false, "You need more players before you can rock the vote!"
	end

	return true
end

function TTT2RTV.StartVote(ply)
	local can, err = TTT2RTV.CanVote(ply)

	if not can then
		ply:PrintMessage(HUD_PRINTTALK, err)

		return
	end

	TTT2RTV.AddVote(ply)
end
concommand.Add("TTT2RTV_start", TTT2RTV.StartVote)

hook.Add("PlayerSay", "TTT2RTVChatCommands", function(ply, text)
	if table.HasValue(TTT2RTV.ChatCommands, string.lower(text)) then
		TTT2RTV.StartVote(ply)

		return ""
	end
end)
