/mob/abstract/ghost/observer/Logout()
	..()
	// This is one of very few spawn()s that we cannot get rid of
	// Yes it needs to be like this
	// No, you're not allowed to use spawn() yourself, unless you're making something that needs to work outside timers
	// Don't be a dumbass, I will always be watching
	spawn(0)
		if(src && !key)	//we've transferred to another mob. This ghost should be deleted.
			qdel(src)
