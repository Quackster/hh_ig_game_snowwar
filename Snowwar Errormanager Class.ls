on construct me
  return 1
  exit
end

on deconstruct me
  return 1
  exit
end

on Refresh me, tTopic, tdata
  if (tdata = 0) then
    return 0
  end if
  if (tTopic = "game_deleted") then
    tAlertStr = "gs_error_game_deleted"
  else
    if (tTopic = "nocredits") then
      tAlertStr = "gs_error_nocredits"
    else
      tAlertStr = ((("gs_error_" & tdata[#request]) & "_") & tdata[#reason])
      if not textExists(tAlertStr) then
        tAlertStr = ("gs_error_" & tdata[#reason])
      end if
    end if
  end if
  return executeMessage(#alert, [#id: "gs_error", #Msg: tAlertStr])
  exit
end
