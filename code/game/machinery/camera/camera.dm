/obj/machinery/camera
	name = "security camera"
	desc = "It's used to monitor rooms."
	icon = 'icons/obj/monitors.dmi'
	icon_state = "camera"
	use_power = POWER_USE_ACTIVE
	idle_power_usage = 5
	active_power_usage = 10
	layer = CAMERA_LAYER
	obj_flags = OBJ_FLAG_MOVES_UNSUPPORTED

	var/list/network = list(NETWORK_STATION)
	var/c_tag = null
	var/c_tag_order = 999
	var/status = 1
	anchored = 1.0
	var/invuln = null
	var/bugged = 0
	var/obj/item/camera_assembly/assembly = null

	var/toughness = 5 //sorta fragile

	// WIRES
	var/datum/wires/camera/wires = null // Wires datum

	//OTHER

	var/view_range = 7
	var/short_range = 2

	var/light_disabled = 0
	var/alarm_on = 0
	var/busy = 0

	var/on_open_network = 0

	var/affected_by_emp_until = 0

/obj/machinery/camera/Initialize()
	wires = new(src)
	assembly = new(src)
	assembly.state = 4
	SSmachinery.all_cameras += src

	// Use this to look for cameras that have the same c_tag.
	if(!isnull(src.c_tag))
		for(var/obj/machinery/camera/C in GLOB.cameranet.cameras)
			var/list/tempnetwork = C.network&src.network
			if(C != src && C.c_tag == src.c_tag && tempnetwork.len)

				#if !defined(UNIT_TEST)
				log_mapping_error("The camera [src.c_tag] at [src.x]-[src.y]-[src.z] conflicts with the c_tag of the camera in [C.x]-[C.y]-[C.z]!")

				#else
				SSunit_tests_config.UT.fail("The camera [src.c_tag] at [src.x]-[src.y]-[src.z] conflicts with the c_tag of the camera in [C.x]-[C.y]-[C.z]!")

				#endif

	if(!src.network || src.network.len < 1)
		if(loc)
			log_mapping_error("[src.name] in [get_area(src)] (x:[src.x] y:[src.y] z:[src.z] has errored. [src.network?"Empty network list":"Null network list"]")
		else
			log_mapping_error("[src.name] in [get_area(src)]has errored. [src.network?"Empty network list":"Null network list"]")
		ASSERT(src.network)
		ASSERT(src.network.len > 0)

	set_pixel_offsets()

	var/list/open_networks = difflist(network, GLOB.restricted_camera_networks)
	on_open_network = open_networks.len
	if(on_open_network)
		GLOB.cameranet.add_source(src)

	return ..()

/obj/machinery/camera/Destroy()
	SSmachinery.all_cameras -= src
	deactivate(null, 0) //kick anyone viewing out
	if(assembly)
		QDEL_NULL(assembly)

	cancelCameraAlarm(force = TRUE)

	QDEL_NULL(wires)

	GLOB.cameranet.cameras -= src

	if(on_open_network)
		GLOB.cameranet.remove_source(src)

	. = ..()
	GC_TEMPORARY_HARDDEL

/obj/machinery/camera/set_pixel_offsets()
	pixel_x = dir & (NORTH|SOUTH) ? 0 : (dir == EAST ? -13 : 13)
	pixel_y = dir & (NORTH|SOUTH) ? (dir == NORTH ? -3 : DEFAULT_WALL_OFFSET) : 0

/obj/machinery/camera/process()
	if((stat & EMPED) && world.time >= affected_by_emp_until)
		stat &= ~EMPED
		cancelCameraAlarm()
		update_icon()
		update_coverage()
	return internal_process()

/obj/machinery/camera/proc/internal_process()
	// motion camera event loop
	if (stat & (EMPED|NOPOWER))
		return
	if(!isMotion())
		. = PROCESS_KILL
		return
	if (detectTime > 0)
		var/elapsed = world.time - detectTime
		if (elapsed > alarm_delay)
			triggerAlarm()
	else if (detectTime == -1)
		for (var/mob/target in motionTargets)
			if (target.stat == 2 || QDELING(target)) lostTarget(target)
			// If not detecting with motion camera...
			if (!area_motion)
				// See if the camera is still in range
				if(!in_range(src, target))
					// If they aren't in range, lose the target.
					lostTarget(target)

/obj/machinery/camera/emp_act(severity)
	. = ..()

	if(!isEmpProof() && prob(100/severity))
		if(!affected_by_emp_until || (world.time < affected_by_emp_until))
			affected_by_emp_until = max(affected_by_emp_until, world.time + (90 SECONDS / severity))
		else
			stat |= EMPED
			set_light(0)
			triggerCameraAlarm()
			kick_viewers()
			update_icon()
			update_coverage()

/obj/machinery/camera/bullet_act(obj/projectile/hitting_projectile, def_zone, piercing_hit)
	. = ..()
	if(. != BULLET_ACT_HIT)
		return .

	take_damage(hitting_projectile.get_structure_damage())

/obj/machinery/camera/ex_act(severity)
	if(src.invuln)
		return

	//camera dies if an explosion touches it!
	if(severity <= 2 || prob(50))
		destroy()

	..() //and give it the regular chance of being deleted outright

/obj/machinery/camera/hitby(atom/movable/hitting_atom, skipcatch, hitpush, blocked, datum/thrownthing/throwingdatum)
	..()
	if (istype(hitting_atom, /obj))
		var/obj/O = hitting_atom
		if (O.throwforce >= src.toughness)
			visible_message(SPAN_WARNING("<B>[src] was hit by [O].</B>"))
		take_damage(O.throwforce)

/obj/machinery/camera/proc/setViewRange(var/num = 7)
	src.view_range = num
	GLOB.cameranet.update_visibility(src, 0)

/obj/machinery/camera/attack_hand(mob/living/carbon/human/user as mob)
	if(!istype(user))
		return

	if(user.species.can_shred(user))
		user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
		set_status(0)
		user.do_attack_animation(src)
		visible_message(SPAN_WARNING("\The [user] slashes at [src]!"))
		playsound(src.loc, 'sound/weapons/slash.ogg', 100, 1)
		add_hiddenprint(user)
		destroy()

/obj/machinery/camera/attackby(obj/item/attacking_item, mob/user)
	update_coverage()
	// DECONSTRUCTION
	if(attacking_item.isscrewdriver())
		//to_chat(user, SPAN_NOTICE("You start to [panel_open ? "close" : "open"] the camera's panel."))
		//if(toggle_panel(user)) // No delay because no one likes screwdrivers trying to be hip and have a duration cooldown
		panel_open = !panel_open
		user.visible_message(SPAN_WARNING("[user] screws the camera's panel [panel_open ? "open" : "closed"]!"),
		SPAN_NOTICE("You screw the camera's panel [panel_open ? "open" : "closed"]."))
		attacking_item.play_tool_sound(get_turf(src), 50)
		return TRUE

	else if((attacking_item.iswirecutter() || attacking_item.ismultitool()) && panel_open)
		interact(user)
		return TRUE

	else if(attacking_item.iswelder() && (wires.CanDeconstruct() || (stat & BROKEN)))
		if(weld(attacking_item, user))
			if(assembly)
				assembly.forceMove(src.loc)
				assembly.anchored = 1
				assembly.camera_name = c_tag
				assembly.camera_network = english_list(network, "Station", ",", ",")
				assembly.update_icon()
				assembly.dir = src.dir
				if(stat & BROKEN)
					assembly.state = 2
					to_chat(user, SPAN_NOTICE("You repaired \the [src] frame."))
				else
					assembly.state = 1
					to_chat(user, SPAN_NOTICE("You cut \the [src] free from the wall."))
					new /obj/item/stack/cable_coil(loc, 2)
				assembly = null //so qdel doesn't eat it.
			qdel(src)
		return TRUE

	// OTHER
	else if (can_use() && (istype(attacking_item, /obj/item/paper)) && isliving(user))
		var/info = null
		var/mob/living/U = user
		var/obj/item/paper/X = null

		var/itemname = ""
		if(istype(attacking_item, /obj/item/paper))
			X = attacking_item
			itemname = X.name
			info = X.info
		to_chat(U, "You hold \a [itemname] up to the camera ...")
		for(var/mob/living/silicon/ai/O in GLOB.living_mob_list)
			var/entry = O.addCameraRecord(itemname,info)
			if(!O.client) continue
			if(U.name == "Unknown")
				to_chat(O, "<b>[U]</b> holds \a [itemname] up to one of your cameras ...<a href='byond://?src=[REF(O)];readcapturedpaper=[REF(entry)]'>view message</a>")
			else
				to_chat(O, "<b><a href='byond://?src=[REF(O)];track2=[REF(O)];track=[REF(U)];trackname=[html_encode(U.name)]'>[U]</a></b> holds \a [itemname] up to one of your cameras ...<a href='byond://?src=[REF(O)];readcapturedpaper=[entry]'>view message</a>")

		for(var/mob/O in GLOB.player_list)
			if (istype(O.machine, /obj/machinery/computer/security))
				var/obj/machinery/computer/security/S = O.machine
				if (S.current_camera == src)
					to_chat(O, "[U] holds \a [itemname] up to one of the cameras ...")
					O << browse("<HTML><HEAD><TITLE>[itemname]</TITLE></HEAD><BODY><TT>[info]</TT></BODY></HTML>", "window=[itemname]") //Force people watching to open the page so they can't see it again)
		return TRUE

	else if (istype(attacking_item, /obj/item/camera_bug))
		if (!src.can_use())
			to_chat(user, SPAN_WARNING("Camera non-functional."))
		else if (src.bugged)
			to_chat(user, SPAN_NOTICE("Camera bug removed."))
			src.bugged = 0
		else
			to_chat(user, SPAN_NOTICE("Camera bugged."))
			src.bugged = 1
		return TRUE

	else if(attacking_item.damtype == DAMAGE_BRUTE || attacking_item.damtype == DAMAGE_BURN) //bashing cameras
		user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
		if (attacking_item.force >= src.toughness)
			user.do_attack_animation(src)
			user.visible_message(SPAN_DANGER("[user] has [LAZYPICK(attacking_item.attack_verb,"attacked")] [src] with [attacking_item]!"))
			if (istype(attacking_item, /obj/item)) //is it even possible to get into attackby() with non-items?
				var/obj/item/I = attacking_item
				if (I.hitsound)
					playsound(loc, I.hitsound, I.get_clamped_volume(), 1, -1)
		take_damage(attacking_item.force)
		return TRUE
	else
		return ..()

/obj/machinery/camera/proc/deactivate(user as mob, var/choice = 1)
	// The only way for AI to reactivate cameras are malf abilities, this gives them different messages.
	if(istype(user, /mob/living/silicon/ai))
		user = null

	if(choice != 1)
		//legacy support, if choice is != 1 then just kick viewers without changing status
		kick_viewers()
	else
		set_status(!src.status)
		if (!(src.status))
			if(user)
				visible_message(SPAN_NOTICE(" [user] has deactivated [src]!"))
			else
				visible_message(SPAN_NOTICE(" [src] clicks and shuts down. "))
			playsound(src.loc, 'sound/items/Wirecutter.ogg', 100, 1)
			icon_state = "[initial(icon_state)]1"
			add_hiddenprint(user)
		else
			if(user)
				visible_message(SPAN_NOTICE(" [user] has reactivated [src]!"))
			else
				visible_message(SPAN_NOTICE(" [src] clicks and reactivates itself. "))
			playsound(src.loc, 'sound/items/Wirecutter.ogg', 100, 1)
			icon_state = initial(icon_state)
			add_hiddenprint(user)

	invalidateCameraCache()

	if(!can_use())
		set_light(0)

	GLOB.cameranet.update_visibility(src)

/obj/machinery/camera/proc/take_damage(var/force, var/message)
	//prob(25) gives an average of 3-4 hits
	if (force >= toughness && (force > toughness*4 || prob(25)))
		destroy()

//Used when someone breaks a camera
/obj/machinery/camera/proc/destroy()
	stat |= BROKEN
	wires.cut_all()

	kick_viewers()
	triggerCameraAlarm()
	update_icon()
	update_coverage()

	//sparks
	spark(loc, 5)
	playsound(loc, /singleton/sound_category/spark_sound, 50, 1)

/obj/machinery/camera/proc/set_status(var/newstatus)
	if (status != newstatus)
		status = newstatus
		update_coverage()
		// now disconnect anyone using the camera
		//Apparently, this will disconnect anyone even if the camera was re-activated.
		//I guess that doesn't matter since they couldn't use it anyway?
		kick_viewers()

/obj/machinery/camera/check_eye(mob/user)
	if(!can_use()) return -1
	if(isXRay()) return SEE_TURFS|SEE_MOBS|SEE_OBJS
	return 0

/obj/machinery/camera/grants_equipment_vision(mob/user)
	return can_use()

//This might be redundant, because of check_eye()
/obj/machinery/camera/proc/kick_viewers()
	for(var/mob/O in GLOB.player_list)
		if (istype(O.machine, /obj/machinery/computer/security))
			var/obj/machinery/computer/security/S = O.machine
			if (S.current_camera == src)
				O.unset_machine()
				O.reset_view(null)
				to_chat(O, "The screen bursts into static.")

/obj/machinery/camera/update_icon()
	if (!status || (stat & BROKEN))
		icon_state = "[initial(icon_state)]1"
	else if (stat & EMPED)
		icon_state = "[initial(icon_state)]emp"
	else
		icon_state = initial(icon_state)

/obj/machinery/camera/proc/triggerCameraAlarm(var/duration = 0)
	alarm_on = 1
	GLOB.camera_alarm.triggerAlarm(loc, src, duration)

/obj/machinery/camera/proc/cancelCameraAlarm(var/force = FALSE)
	if(wires.is_cut(WIRE_ALARM) && !force)
		return

	alarm_on = 0
	GLOB.camera_alarm.clearAlarm(loc, src)

//if false, then the camera is listed as DEACTIVATED and cannot be used
/obj/machinery/camera/proc/can_use()
	if(!status)
		return 0
	if(stat & (EMPED|BROKEN))
		return 0
	return 1

/obj/machinery/camera/proc/can_see()
	var/list/see = null
	var/turf/pos = get_turf(src)
	if(!pos)
		return list()

	if(isXRay())
		see = range(view_range, pos)
	else
		see = get_hear(view_range, pos)
	return see

/atom/proc/auto_turn()
	//Automatically turns based on nearby walls.
	var/turf/simulated/wall/T = null
	for(var/i = 1, i <= 8; i += i)
		T = get_ranged_target_turf(src, i, 1)
		if(istype(T))
			//If someone knows a better way to do this, let me know. -Giacom
			switch(i)
				if(NORTH)
					src.set_dir(SOUTH)
				if(SOUTH)
					src.set_dir(NORTH)
				if(WEST)
					src.set_dir(EAST)
				if(EAST)
					src.set_dir(WEST)
			break

//Return a working camera that can see a given mob
//or null if none
/proc/seen_by_camera(var/mob/M)
	for(var/obj/machinery/camera/C in oview(4, M))
		if(C.can_use())	// check if camera disabled
			return C
	return null

/proc/near_range_camera(var/mob/M)
	for(var/obj/machinery/camera/C in range(4, M))
		if(C.can_use())	// check if camera disabled
			return C
	return null

/obj/machinery/camera/proc/weld(var/obj/item/weldingtool/WT, var/mob/user)

	if(busy)
		return 0
	if(!WT.isOn())
		return 0

	// Do after stuff here
	to_chat(user, SPAN_NOTICE("You start to weld the [src].."))
	playsound(src.loc, 'sound/items/Welder.ogg', 50, 1)
	user.flash_act(FLASH_PROTECTION_MAJOR)
	busy = 1
	if(WT.use_tool(src, user, 100, volume = 50))
		busy = 0
		if(!WT.isOn())
			return 0
		return 1
	busy = 0
	return 0

/obj/machinery/camera/interact(mob/living/user as mob)
	if(!panel_open || istype(user, /mob/living/silicon/ai))
		return

	if(stat & BROKEN)
		to_chat(user, SPAN_WARNING("\The [src] is broken."))
		return

	user.set_machine(src)
	wires.interact(user)

/obj/machinery/camera/proc/add_network(var/network_name)
	add_networks(list(network_name))

/obj/machinery/camera/proc/remove_network(var/network_name)
	remove_networks(list(network_name))

/obj/machinery/camera/proc/add_networks(var/list/networks)
	var/network_added
	network_added = 0
	for(var/network_name in networks)
		if(!(network_name in src.network))
			network += network_name
			network_added = 1

	if(network_added)
		update_coverage(1)

/obj/machinery/camera/proc/remove_networks(var/list/networks)
	var/network_removed
	network_removed = 0
	for(var/network_name in networks)
		if(network_name in src.network)
			network -= network_name
			network_removed = 1

	if(network_removed)
		update_coverage(1)

/obj/machinery/camera/proc/replace_networks(var/list/networks)
	if(networks.len != network.len)
		network = networks
		update_coverage(1)
		return

	for(var/new_network in networks)
		if(!(new_network in network))
			network = networks
			update_coverage(1)
			return

/obj/machinery/camera/proc/clear_all_networks()
	if(network.len)
		network.Cut()
		update_coverage(1)

/obj/machinery/camera/proc/nano_structure()
	var/cam = list()
	cam["name"] = sanitize(c_tag)
	cam["deact"] = !can_use()
	cam["camera"] = "[REF(src)]"
	cam["x"] = x
	cam["y"] = y
	cam["z"] = z
	return cam

// Resets the camera's wires to fully operational state. Used by one of Malfunction abilities.
/obj/machinery/camera/proc/reset_wires()
	if(!wires)
		return
	if (stat & BROKEN) // Fix the camera
		stat &= ~BROKEN
	wires.cut_all(src)
	wires.repair()
	update_icon()
	update_coverage()
