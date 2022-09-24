on construct me
  return 1
  exit
end

on deconstruct me
  me.removeControllingAvatar()
  return 1
  exit
end

on define me, tGameObject
  executeMessage(#ig_store_gameplayer_info, tGameObject)
  return 1
  exit
end

on removeControllingAvatar me
  return me.getGameSystem().executeGameObjectEvent(me.pGameObjectSyncValues[#human_id], #reset_player)
  exit
end
