local CATEGORY_NAME = "RoleVote"

------------------------------ VoteMap ------------------------------
function AMB_rolevote(calling_ply, votetime, should_cancel)
	if not should_cancel then
		RoleVote.Start(votetime, nil, nil, nil)
		ulx.fancyLogAdmin(calling_ply, "#A called a rolevote!")
	else
		RoleVote.Cancel()
		ulx.fancyLogAdmin(calling_ply, "#A canceled the rolevote")
	end
end

local rolevotecmd = ulx.command(CATEGORY_NAME, "rolevote", AMB_rolevote, "!rolevote")
rolevotecmd:addParam{type = ULib.cmds.NumArg, min = 15, default = 25, hint = "time", ULib.cmds.optional, ULib.cmds.round}
rolevotecmd:addParam{type = ULib.cmds.BoolArg, invisible = true}
rolevotecmd:defaultAccess(ULib.ACCESS_ADMIN)
rolevotecmd:help("Invokes the role vote logic")
rolevotecmd:setOpposite("unrolevote", {_, _, true}, "!unrolevote")
