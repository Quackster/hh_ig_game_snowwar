on construct me
  return 1
  exit
end

on deconstruct me
  return 1
  exit
end

on Refresh me, tTopic, tdata
  call(symbol(("handle_" & tTopic)), me, tdata)
  return 1
  exit
end

on handle_msgstruct_objects me, tdata
  tList = []
  tCount = tdata.line.count
  repeat with i = 1 to tCount
    tLine = tdata.line[i]
    if (length(tLine) > 5) then
      tObj = [:]
      tObj[#id] = tLine.word[1]
      tObj[#class] = tLine.word[2]
      tObj[#x] = integer(tLine.word[3])
      tObj[#y] = integer(tLine.word[4])
      tObj[#h] = integer(tLine.word[5])
      if (tLine.word.count = 6) then
        tdir = (integer(tLine.word[6]) mod 8)
        tObj[#direction] = [tdir, tdir, tdir]
        tObj[#dimensions] = 0
      else
        tWidth = integer(tLine.word[6])
        tHeight = integer(tLine.word[7])
        tObj[#dimensions] = [tWidth, tHeight]
        tObj[#x] = ((tObj[#x] + tObj[#width]) - 1)
        tObj[#y] = ((tObj[#y] + tObj[#height]) - 1)
      end if
      tVarKey = (("snowwar.object_" & tObj[#class]) & ".height")
      if variableExists(tVarKey) then
        tObj[#height] = getIntVariable(tVarKey)
      else
        tObj[#height] = 0
      end if
      if (tObj[#id] <> EMPTY) then
        tList.add(tObj)
      end if
    end if
  end repeat
  return me.getGameSystem().getWorld().storeObjects(tList)
  exit
end

on handle_msgstruct_instancelist me, tMsg
  tConn = tMsg.connection
  tResult = [:]
  tCreatedCount = tConn.GetIntFrom()
  repeat with i = 1 to tCreatedCount
    tInstance = me.parse_created_instance(tConn)
    tResult.addProp(string(tInstance[#id]), tInstance)
  end repeat
  tStartedCount = tConn.GetIntFrom()
  repeat with i = 1 to tStartedCount
    tInstance = me.parse_started_instance(tConn)
    tResult.addProp(string(tInstance[#id]), tInstance)
  end repeat
  tFinishedCount = tConn.GetIntFrom()
  repeat with i = 1 to tFinishedCount
    tInstance = me.parse_finished_instance(tConn)
    tResult.addProp(string(tInstance[#id]), tInstance)
  end repeat
  return me.getGameSystem().sendGameSystemEvent(#instancelist, tResult)
  return tResult
  exit
end

on handle_msgstruct_gameinstance me, tMsg
  tConn = tMsg.connection
  tStateInt = tConn.GetIntFrom()
  tstate = [#created, #started, #finished][(tStateInt + 1)]
  if (tstate = #created) then
    tResult = me.parse_created_instance(tConn)
    tResult.addProp(#numSpectators, tConn.GetIntFrom())
    tNumTeams = tConn.GetIntFrom()
    tTeams = []
    repeat with i = 1 to tNumTeams
      tList = []
      tNumPlayers = tConn.GetIntFrom()
      repeat with j = 1 to tNumPlayers
        tList.add(me.parse_team_player(tConn))
      end repeat
      tTeams.add([#players: tList, #id: i])
    end repeat
    tResult.addProp(#numTeams, tNumTeams)
    tResult.addProp(#teams, tTeams)
  else
    if (tstate = #started) then
      tResult = me.parse_started_instance(tConn)
      tNumTeams = tConn.GetIntFrom()
      tTeams = []
      repeat with i = 1 to tNumTeams
        tList = []
        tNumPlayers = tConn.GetIntFrom()
        repeat with j = 1 to tNumPlayers
          tList.add([#name: tConn.GetStrFrom()])
        end repeat
        tTeams.add([#players: tList, #id: i])
      end repeat
      tResult.addProp(#numTeams, tNumTeams)
      tResult.addProp(#teams, tTeams)
    else
      if (tstate = #finished) then
        tResult = me.parse_finished_instance(tConn)
        tNumTeams = tConn.GetIntFrom()
        tTeamsUnsorted = []
        repeat with i = 1 to tNumTeams
          tList = [#players: []]
          tNumPlayers = tConn.GetIntFrom()
          repeat with j = 1 to tNumPlayers
            tPlayer = [:]
            tPlayer.addProp(#name, tConn.GetStrFrom())
            tPlayer.addProp(#score, tConn.GetIntFrom())
            tList[#players].add(tPlayer)
          end repeat
          tList.addProp(#score, tConn.GetIntFrom())
          tTeamsUnsorted.add(tList)
        end repeat
        tResult.addProp(#numTeams, tNumTeams)
        tTeams = []
        repeat with tTeamId = 1 to tNumTeams
          tList = [#players: [], #id: tTeamId, #score: tTeamsUnsorted[tTeamId][#score]]
          tTeamPlayers = tTeamsUnsorted[tTeamId][#players]
          repeat with j = 1 to tTeamPlayers.count
            tPlayer = [:]
            tPlayer.addProp(#name, tTeamPlayers[j][#name])
            tPlayer.addProp(#score, tTeamPlayers[j][#score])
            tPlayerPos = 1
            if (tList[#players].count > 0) then
              repeat while (tList[#players][tPlayerPos][#score] > tPlayer[#score])
                tPlayerPos = (tPlayerPos + 1)
                if (tPlayerPos > tList[#players].count) then
                  next repeat
                end if
              end repeat
            end if
            tList[#players].addAt(tPlayerPos, tPlayer)
          end repeat
          tTeams.add(tList)
        end repeat
        tPlayerPos = 1
        tResult.addProp(#teams, tTeams)
      end if
    end if
  end if
  tResult.addProp(#state, tstate)
  return me.getGameSystem().sendGameSystemEvent(#gameinstance, tResult)
  exit
end

on handle_msgstruct_fullgamestatus me, tMsg
  tGameSystem = me.getGameSystem()
  if (tGameSystem = 0) then
    return 0
  end if
  tConn = tMsg.connection
  tdata = [:]
  tStateInt = tConn.GetIntFrom()
  tTimeToNextState = tConn.GetIntFrom()
  tStateDuration = tConn.GetIntFrom()
  tNumObjects = tConn.GetIntFrom()
  tObjectIdList = []
  tGameObjects = []
  repeat with i = 1 to tNumObjects
    tGameObject = me.parse_snowwar_gameobject(tConn)
    if listp(tGameObject) then
      tGameObjects.add(tGameObject)
      tObjectIdList.add(string(tGameObject[#id]))
    end if
  end repeat
  tdata.addProp(#game_objects, tGameObjects)
  tGameSystem.getVarMgr().set(#tournament_flag, tConn.GetBoolFrom())
  tGameSystem.sendGameSystemEvent(#set_number_of_teams, tConn.GetIntFrom())
  tGameSystem.clearTurnBuffer()
  tGameSystem.sendGameSystemEvent(#verify_game_object_id_list, tObjectIdList)
  repeat with i = 1 to count(getAt(tdata, #game_objects))
    tGameObject = getAt(getAt(tdata, #game_objects), i)
    if (tGameSystem.getGameObject(tGameObject[#id]) = 0) then
      tGameSystem.sendGameSystemEvent(#create_game_object, tGameObject)
      next repeat
    end if
    tGameSystem.sendGameSystemEvent(#update_game_object, tGameObject)
  end repeat
  tGameSystem.sendGameSystemEvent(#update_game_visuals)
  tGameSystem.startTurnManager()
  return me.parse_gamestatus(tConn)
  exit
end

on handle_msgstruct_gamestart me, tMsg
  tConn = tMsg.connection
  tdata = [:]
  tdata.addProp(#time_until_game_end, tConn.GetIntFrom())
  return me.getGameSystem().sendGameSystemEvent(#gamestart, tdata)
  exit
end

on handle_msgstruct_gameend me, tMsg
  tConn = tMsg.connection
  tdata = [:]
  tdata.addProp(#time_until_game_reset, tConn.GetIntFrom())
  tNumTeams = tConn.GetIntFrom()
  tTeamScores = []
  repeat with tTeamNum = 1 to tNumTeams
    tNumPlayers = tConn.GetIntFrom()
    tPlayers = [:]
    repeat with tPlayer = 1 to tNumPlayers
      tPlayerId = tConn.GetIntFrom()
      tPlayerName = tConn.GetStrFrom()
      tPlayerScore = tConn.GetIntFrom()
      tPlayers.addProp(tPlayerName, [#id: tPlayerId, #name: tPlayerName, #score: tPlayerScore])
    end repeat
    if (tNumPlayers > 0) then
      tTeamScore = tConn.GetIntFrom()
    else
      tTeamScore = 0
    end if
    tTeamScores.add([#players: tPlayers, #score: tTeamScore])
  end repeat
  tdata.addProp(#gameend_scores, tTeamScores)
  return me.getGameSystem().sendGameSystemEvent(#gameend, tdata)
  exit
end

on handle_msgstruct_gamereset me, tMsg
  tConn = tMsg.connection
  tdata = [:]
  tNumObjects = tConn.GetIntFrom()
  tGameObjects = []
  tObjectIdList = []
  repeat with i = 1 to tNumObjects
    tGameObject = me.parse_snowwar_gameobject(tConn)
    if listp(tGameObject) then
      tGameObjects.add(tGameObject)
      tObjectIdList.add(string(tGameObject[#id]))
    end if
  end repeat
  tdata.addProp(#game_objects, tGameObjects)
  tGameSystem = me.getGameSystem()
  tHeightMap = tConn.GetStrFrom()
  tWorldWidth = tHeightMap.line[1].length
  tWorldLength = tHeightMap.line.count
  me.store_heightmap(tHeightMap, tWorldWidth, tWorldLength)
  tGameSystem.clearTurnBuffer()
  tGameSystem.sendGameSystemEvent(#verify_game_object_id_list, tObjectIdList)
  repeat with i = 1 to count(getAt(tdata, #game_objects))
    tGameObject = getAt(getAt(tdata, #game_objects), i)
    if (tGameSystem.getGameObject(tGameObject[#id]) = 0) then
      tGameSystem.sendGameSystemEvent(#create_game_object, tGameObject)
      next repeat
    end if
    tGameSystem.sendGameSystemEvent(#update_game_object, tGameObject)
  end repeat
  tTeamNumber = tConn.GetIntFrom()
  tGameSystem.sendGameSystemEvent(#set_number_of_teams, tTeamNumber)
  tGameSystem.sendGameSystemEvent(#update_game_visuals)
  return tGameSystem.sendGameSystemEvent(#gamereset, tdata)
  exit
end

on store_heightmap me, tdata, tWorldWidth, tWorldHeight
  tRoomComponent = getObject(#room_component)
  if (tRoomComponent = 0) then
    return 0
  end if
  tRoomComponent.getInterface().getGeometry().loadHeightMap(tdata)
  tGameSystem = me.getGameSystem()
  if (tGameSystem = 0) then
    return 0
  end if
  return tGameSystem.getWorld().storeHeightmap(tdata, tWorldWidth, tWorldHeight)
end

on handle_msgstruct_gameplayerinfo me, tMsg
  tConn = tMsg.connection
  tdata = [:]
  tNumPlayers = tConn.GetIntFrom()
  repeat with i = 1 to tNumPlayers
    tID = tConn.GetIntFrom()
    tValue = tConn.GetStrFrom()
    tSkill = tConn.GetStrFrom()
    tdata.addProp(string(tID), [#id: tID, #skillvalue: tValue, #skilllevel: tSkill])
  end repeat
  return me.getGameSystem().sendGameSystemEvent(#gameplayerinfo, tdata)
  exit
end

on handle_msgstruct_gamestatus me, tMsg
  tConn = tMsg.connection
  return me.parse_gamestatus(tConn)
  exit
end

on parse_gamestatus me, tConn
  tGameSystem = me.getGameSystem()
  if (tGameSystem = 0) then
    return 0
  end if
  tTurnNum = tConn.GetIntFrom()
  tCheckSum = tConn.GetIntFrom()
  tNumSubturns = tConn.GetIntFrom()
  tTurn = tGameSystem.getNewTurnContainer()
  if not objectp(tTurn) then
    return error(me, "Cannot create turn container!", #parse_gamestatus)
  end if
  tTurn.setNumber(tTurnNum)
  tTurn.SetChecksum(tCheckSum)
  tSubTurnIndex = []
  repeat with tSubTurnNum = 1 to tNumSubturns
    tSubTurnIndex[tSubTurnNum] = []
    tNumEvents = tConn.GetIntFrom()
    repeat with tEventNum = 1 to tNumEvents
      tEvent = me.parse_event(tConn)
      if (tEvent = 0) then
        return error(me, "SERVER ERROR: No event received when expected!", #parse_gamestatus)
      end if
      tTurn.AddElement(tSubTurnNum, tEvent)
    end repeat
    if (tNumEvents = 0) then
      tTurn.AddElement(tSubTurnNum, VOID)
    end if
  end repeat
  return tGameSystem.sendGameSystemEvent(#gamestatus_turn, tTurn)
  exit
end

on parse_snowwar_gameobject me, tConn
  tdata = [:]
  tdata.addProp(#type, tConn.GetIntFrom())
  tID = tConn.GetIntFrom()
  tdata.addProp(#int_id, tID)
  tdata.addProp(#id, string(tID))
  if (tdata[#type] = 0) then
    tObjectData = me.parse_snowwar_player_gameobjectvariables(tdata.duplicate(), tConn)
    tdata.addProp(#objectDataStruct, tObjectData)
    tdata.addProp(#str_type, "player")
  else
    if (tdata[#type] = 1) then
      tObjectData = me.parse_snowwar_snowball_gameobjectvariables(tdata.duplicate(), tConn)
      tdata.addProp(#objectDataStruct, tObjectData)
      tdata.addProp(#str_type, "snowball")
    else
      if (tdata[#type] = 2) then
        return 0
      else
        if (tdata[#type] = 3) then
          tObjectData = me.parse_snowwar_large_snowball_gameobjectvariables(tdata.duplicate(), tConn)
          tdata.addProp(#objectDataStruct, tObjectData)
          tdata.addProp(#str_type, "large_snowball")
        else
          if (tdata[#type] = 4) then
            tObjectData = me.parse_snowwar_snowball_machine_gameobjectvariables(tdata.duplicate(), tConn)
            tdata.addProp(#objectDataStruct, tObjectData)
            tdata.addProp(#str_type, "snowball_machine")
          else
            if (tdata[#type] = 5) then
              tObjectData = me.parse_snowwar_avatar_gameobjectvariables(tdata.duplicate(), tConn)
              tdata.addProp(#objectDataStruct, tObjectData)
              repeat with i = 1 to tObjectData.count
                tdata.addProp(tObjectData.getPropAt(i), tObjectData[i])
              end repeat
              tdata.addProp(#human_id, tdata[#id])
              tdata.addProp(#dirBody, tdata[#body_direction])
              tdata.addProp(#name, tConn.GetStrFrom())
              tdata.addProp(#mission, tConn.GetStrFrom())
              tdata.addProp(#figure, tConn.GetStrFrom())
              tdata.addProp(#sex, tConn.GetStrFrom())
              tdata.addProp(#str_type, "avatar")
            else
              error(me, ("Unsupported game object type:" && tdata[#type]), #parse_snowwar_gameobject)
            end if
          end if
        end if
      end if
    end if
  end if
  tExtraProps = ["collisionshape_type", "height", "collisionshape_radius"]
  repeat with i = 1 to count(tExtraProps)
    tProp = getAt(tExtraProps, i)
    if variableExists(((("snowwar.object_" & tdata[#str_type]) & ".") & tProp)) then
      tdata.addProp(symbol(("gameobject_" & tProp)), getVariable(((("snowwar.object_" & tdata[#str_type]) & ".") & tProp)))
    end if
  end repeat
  return tdata
  exit
end

on parse_snowwar_snowball_gameobjectvariables me, tdata, tConn
  tdata.addProp(#x, tConn.GetIntFrom())
  tdata.addProp(#y, tConn.GetIntFrom())
  tdata.addProp(#z, tConn.GetIntFrom())
  tdata.addProp(#movement_direction, tConn.GetIntFrom())
  tdata.addProp(#trajectory, tConn.GetIntFrom())
  tdata.addProp(#time_to_live, tConn.GetIntFrom())
  tdata.addProp(#int_thrower_id, tConn.GetIntFrom())
  tdata.addProp(#parabola_offset, tConn.GetIntFrom())
  return tdata
  exit
end

on parse_snowwar_player_gameobjectvariables me, tdata, tConn
  tdata.addProp(#room_index, tConn.GetIntFrom())
  tdata.addProp(#human_id, tConn.GetIntFrom())
  return tdata
  exit
end

on parse_snowwar_avatar_gameobjectvariables me, tdata, tConn
  tdata.addProp(#x, tConn.GetIntFrom())
  tdata.addProp(#y, tConn.GetIntFrom())
  tdata.addProp(#body_direction, tConn.GetIntFrom())
  tdata.addProp(#hit_points, tConn.GetIntFrom())
  tdata.addProp(#snowball_count, tConn.GetIntFrom())
  tdata.addProp(#is_bot, tConn.GetIntFrom())
  tdata.addProp(#activity_timer, tConn.GetIntFrom())
  tdata.addProp(#activity_state, tConn.GetIntFrom())
  tdata.addProp(#next_tile_x, tConn.GetIntFrom())
  tdata.addProp(#next_tile_y, tConn.GetIntFrom())
  tdata.addProp(#move_target_x, tConn.GetIntFrom())
  tdata.addProp(#move_target_y, tConn.GetIntFrom())
  tdata.addProp(#score, tConn.GetIntFrom())
  tdata.addProp(#player_id, tConn.GetIntFrom())
  tdata.addProp(#team_id, tConn.GetIntFrom())
  tdata.addProp(#room_index, tConn.GetIntFrom())
  return tdata
  exit
end

on parse_snowwar_large_snowball_gameobjectvariables me, tdata, tConn
  tdata.addProp(#x, tConn.GetIntFrom())
  tdata.addProp(#y, tConn.GetIntFrom())
  return tdata
  exit
end

on parse_snowwar_snowball_machine_gameobjectvariables me, tdata, tConn
  tdata.addProp(#x, tConn.GetIntFrom())
  tdata.addProp(#y, tConn.GetIntFrom())
  tdata.addProp(#snowball_count, tConn.GetIntFrom())
  return tdata
  exit
end

on parse_event me, tConn
  tEventType = tConn.GetIntFrom()
  if (tEventType = 0) then
    tEvent = me.parse_snowwar_gameobject(tConn)
    tEvent.addProp(#event_type, 0)
  else
    if (tEventType = 1) then
      tIntKeyList = [#int_id]
    else
      if (tEventType = 2) then
        tIntKeyList = [#int_id, #x, #y]
      else
        if (tEventType = 3) then
          tIntKeyList = [#int_id, #int_target_id, #throw_height]
        else
          if (tEventType = 4) then
            tIntKeyList = [#int_id, #targetX, #targetY, #throw_height]
          else
            if (tEventType = 5) then
              tIntKeyList = [#int_thrower_id, #int_id, #hit_direction]
            else
              if (tEventType = 6) then
                tIntKeyList = [#x, #y]
              else
                if (tEventType = 7) then
                  tIntKeyList = [#int_id]
                else
                  if (tEventType = 8) then
                    tIntKeyList = [#int_id, #int_thrower_id, #targetX, #targetY, #trajectory]
                  else
                    if (tEventType = 9) then
                      tIntKeyList = [#int_id, #int_thrower_id, #hit_direction]
                    else
                      if (tEventType = 10) then
                        tIntKeyList = []
                      else
                        if (tEventType = 11) then
                          tIntKeyList = [#int_machine_id]
                        else
                          if (tEventType = 12) then
                            tIntKeyList = [#int_player_id, #int_machine_id]
                          else
                            return error(me, "Undefined event sent by server, parsing cannot continue!", #handle_gamestatus)
                          end if
                        end if
                      end if
                    end if
                  end if
                end if
              end if
            end if
          end if
        end if
      end if
    end if
  end if
  if listp(tIntKeyList) then
    tEvent = [#event_type: tEventType]
    repeat with i = 1 to count(tIntKeyList)
      tKey = getAt(tIntKeyList, i)
      tEvent.addProp(tKey, tConn.GetIntFrom())
    end repeat
    if (tEvent.findPos(#int_id) > 0) then
      tEvent.addProp(#id, string(tEvent[#int_id]))
    end if
  end if
  return tEvent
  exit
end

on parse_created_instance me, tConn
  tResult = [:]
  tResult.addProp(#id, tConn.GetIntFrom())
  tResult.addProp(#name, tConn.GetStrFrom())
  tResult.addProp(#host, me.parse_team_player(tConn))
  tResult.addProp(#state, #created)
  tResult.addProp(#gameLength, tConn.GetIntFrom())
  tResult.addProp(#fieldType, tConn.GetIntFrom())
  return tResult
  exit
end

on parse_started_instance me, tConn
  tResult = [:]
  tResult.addProp(#id, tConn.GetIntFrom())
  tResult.addProp(#name, tConn.GetStrFrom())
  tResult.addProp(#host, [#name: tConn.GetStrFrom()])
  tResult.addProp(#state, #started)
  tResult.addProp(#gameLength, tConn.GetIntFrom())
  tResult.addProp(#fieldType, tConn.GetIntFrom())
  return tResult
  exit
end

on parse_finished_instance me, tConn
  tResult = [:]
  tResult.addProp(#id, tConn.GetIntFrom())
  tResult.addProp(#name, tConn.GetStrFrom())
  tResult.addProp(#host, [#name: tConn.GetStrFrom()])
  tResult.addProp(#state, #finished)
  tResult.addProp(#gameLength, tConn.GetIntFrom())
  tResult.addProp(#fieldType, tConn.GetIntFrom())
  return tResult
  exit
end

on parse_team_player me, tConn
  tResult = [:]
  tResult.addProp(#id, tConn.GetIntFrom())
  tResult.addProp(#name, tConn.GetStrFrom())
  return tResult
  exit
end

on parse_gamestatus_player me, tConn
  tdata = [:]
  tdata.addProp(#id, tConn.GetIntFrom())
  tdata.addProp(#locX, tConn.GetIntFrom())
  tdata.addProp(#locY, tConn.GetIntFrom())
  tdata.addProp(#dirBody, tConn.GetIntFrom())
  return tdata
  exit
end
