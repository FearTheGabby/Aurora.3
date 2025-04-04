#define UNBUCKLED 0
#define PARTIALLY_BUCKLED 1
#define FULLY_BUCKLED 2

/mob/Destroy()//This makes sure that mobs with clients/keys are not just deleted from the game.
	MOB_STOP_THINKING(src)

	GLOB.mob_list -= src
	GLOB.dead_mob_list -= src
	GLOB.living_mob_list -= src
	unset_machine()
	QDEL_NULL(hud_used)
	lose_hearing_sensitivity()

	QDEL_LIST(spell_masters)
	remove_screen_obj_references()

	if(client)
		for(var/atom/movable/AM in client.screen)
			qdel(AM)
		client.screen = list()

	if (mind)
		mind.handle_mob_deletion(src)

	for(var/infection in viruses)
		qdel(infection)

	for(var/cc in client_colors)
		qdel(cc)

	client_colors = null
	viruses.Cut()
	item_verbs = null

	//Added this to prevent nonliving mobs from ghostising
	//The only non 'living' mobs are:
		//observers (ie ghosts),
		//new_player, an abstraction used to handle people who are sitting in the lobby
		//Freelook, an abstraction used to handle the AI looking through cameras, and possibly remote viewing mutation

	//None of these mobs can 'die' in any sense, and none of them should be able to become ghosts.
	//Ghosts are the only ones that even technically 'exist' and aren't just an abstraction using mob code for convenience
	//Well, those and storytellers. This code is seriously shit and needs a rework, but who gives a fuck right now. Sue me.
	if (istype(src, /mob/living) && !isstoryteller(src))
		ghostize()

	if (istype(src.loc, /atom/movable))
		var/atom/movable/AM = src.loc
		LAZYREMOVE(AM.contained_mobs, src)

	QDEL_NULL(ability_master)

	if(click_handlers)
		QDEL_LIST(click_handlers)

	return ..()

/mob/New()
	// This needs to happen IMMEDIATELY. I'm sorry :(
	GenerateTag()
	return ..()

/mob/proc/remove_screen_obj_references()
	flash = null
	blind = null
	hands = null
	pullin = null
	purged = null
	internals = null
	oxygen = null
	i_select = null
	m_select = null
	toxin = null
	fire = null
	bodytemp = null
	healths = null
	throw_icon = null
	nutrition_icon = null
	hydration_icon = null
	pressure = null
	damageoverlay = null
	pain = null
	item_use_icon = null
	gun_move_icon = null
	gun_setting_icon = null
	spell_masters = null
	zone_sel = null

/mob/var/should_add_to_mob_list = TRUE
/mob/Initialize(mapload)
	. = ..()
	if(should_add_to_mob_list)
		GLOB.mob_list += src
		if(stat == DEAD)
			GLOB.dead_mob_list += src
		else
			GLOB.living_mob_list += src

	if (!ckey && mob_thinks)
		MOB_START_THINKING(src)

	update_emotes()

	become_hearing_sensitive()

/**
 * Generate the tag for this mob
 *
 * This is simply "mob_"+ a global incrementing counter that goes up for every mob
 */
/mob/GenerateTag()
	. = ..()
	tag = "mob_[next_mob_id++]"

/mob/verb/say_wrapper()
	set name = ".Say"
	set hidden = TRUE
	winset(src, null, "command=[client.tgui_say_create_open_command(SAY_CHANNEL)]")

/mob/verb/me_wrapper()
	set name = ".Me"
	set hidden = TRUE
	winset(src, null, "command=[client.tgui_say_create_open_command(ME_CHANNEL)]")

/client/verb/typing_indicator()
	set name = "Show/Hide Typing Indicator"
	set category = "Preferences.Game"
	set desc = "Toggles showing an indicator when you are typing emote or say message."
	prefs.toggles ^= HIDE_TYPING_INDICATOR
	prefs.save_preferences()
	to_chat(src, "You will [(prefs.toggles & HIDE_TYPING_INDICATOR) ? "no longer" : "now"] display a typing indicator.")
	feedback_add_details("admin_verb","TID") //If you are copy-pasting this, ensure the 2nd parameter is unique to the new proc!

/mob/proc/set_stat(var/new_stat)
	. = stat != new_stat
	if(.)
		stat = new_stat
		remove_all_indicators()

/mob/show_message(msg, type, alt, alt_type)//Message, type of message (1 or 2), alternative message, alt message type (1 or 2)

	if(!client)	return

	if (type)
		if(type & 1 && (sdisabilities & BLIND || blinded || paralysis) )//Vision related
			if (!( alt ))
				return
			else
				msg = alt
				type = alt_type
		if (type & 2 && isdeaf(src))//Hearing related
			if (!( alt ))
				return
			else
				msg = alt
				type = alt_type
				if ((type & 1 && sdisabilities & BLIND))
					return
	// Added voice muffling for Issue 41.
	if(stat == UNCONSCIOUS || sleeping > 0)
		to_chat(src, "<I>... You can almost hear someone talking ...</I>")
	else
		to_chat(src, msg)
	return


/mob/visible_message(message, self_message, blind_message, range = world.view, show_observers = TRUE, intent_message = null, intent_range = 7)
	var/list/messageturfs = list() //List of turfs we broadcast to.
	var/list/messagemobs = list() //List of living mobs nearby who can hear it, and distant ghosts who've chosen to hear it
	var/list/messageobjs = list() //list of objs nearby who can see it
	for (var/turf in view(range, get_turf(src)))
		messageturfs += turf

	for(var/A in GLOB.player_list)
		var/mob/M = A
		if (QDELETED(M))
			warning("Null or QDELETED object [DEBUG_REF(M)] found in player list! Removing.")
			GLOB.player_list -= M
			continue
		if (!M.client || istype(M, /mob/abstract/new_player))
			continue
		if((get_turf(M) in messageturfs) || (show_observers && isghost(M) && (M.client.prefs.toggles & CHAT_GHOSTSIGHT)))
			messagemobs += M

	for(var/o in GLOB.listening_objects)
		var/obj/O = o
		var/turf/O_turf = get_turf(O)
		if(O && (O_turf in messageturfs))
			messageobjs += O

	for(var/A in messagemobs)
		var/mob/M = A
		if(isghost(M))
			M.show_message("[ghost_follow_link(src, M)] [message]", 1)
			continue
		if(self_message && M == src)
			M.show_message(self_message, 1, blind_message, 2)
		else if(is_invisible_to(M))  // Cannot view the invisible, but you can hear it.
			if(blind_message)
				M.show_message(blind_message, 2)
		else
			M.show_message(message, 1, blind_message, 2)

	for(var/o in messageobjs)
		var/obj/O = o
		O.see_emote(src, message)

	var/list/hear_clients = list()
	for(var/mob/M in messagemobs)
		if(M.client)
			hear_clients += M.client


	if(intent_message)
		intent_message(intent_message, intent_range, messagemobs + src)

	//Multiz, have shadow do same
	if(bound_overlay)
		bound_overlay.visible_message(message, blind_message, range)

// Designed for mobs contained inside things, where a normal visible message wont actually be visible
// Useful for visible actions by pAIs, and held mobs
// Broadcaster is the place the action will be seen/heard from, mobs in sight of THAT will see the message. This is generally the object or mob that src is contained in
// message is the message output to anyone who can see e.g. "[src] does something!"
// self_message (optional) is what the src mob sees  e.g. "You do something!"
// blind_message (optional) is what blind people will hear e.g. "You hear something!"
//This is obsolete now
/mob/proc/contained_visible_message(var/atom/broadcaster, var/message, var/self_message, var/blind_message)
	var/self_served = 0
	for(var/mob/M in viewers(broadcaster))
		if(self_message && M==src)
			M.show_message(self_message, 1, blind_message, 2)
			self_served = 1
		else if(M.see_invisible < invisibility)  // Cannot view the invisible, but you can hear it.
			if(blind_message)
				M.show_message(blind_message, 2)
		else
			M.show_message(message, 1, blind_message, 2)

	if (!self_served)
		src.show_message(self_message, 1, blind_message, 2)

// Returns an amount of power drawn from the object (-1 if it's not viable).
// If drain_check is set it will not actually drain power, just return a value.
// If surge is set, it will destroy/damage the recipient and not return any power.
// Not sure where to define this, so it can sit here for the rest of time.
/atom/proc/drain_power(var/drain_check, var/surge, var/amount = 0)
	return -1

// Show a message to all mobs and objects in earshot of this one
// This would be for audible actions by the src mob
// message is the message output to anyone who can hear.
// self_message (optional) is what the src mob hears.
// deaf_message (optional) is what deaf people will see.
// hearing_distance (optional) is the range, how many tiles away the message can be heard.
/mob/audible_message(var/message, var/deaf_message, var/hearing_distance, var/self_message, var/ghost_hearing = GHOSTS_ALL_HEAR)
	if(!hearing_distance)
		hearing_distance = world.view

	var/list/hearers = get_hearers_in_view(hearing_distance, src)

	for (var/atom/movable/AM as anything in hearers)
		if(self_message && AM == src)
			AM.show_message("[get_accent_icon(null, src)] [self_message]", 2, deaf_message, 1)
			continue

		AM.show_message("[get_accent_icon(null, ismob(AM) ? AM : src)] [message]", 2, deaf_message, 1)

/mob/proc/findname(msg)
	for(var/mob/M in GLOB.mob_list)
		if (M.real_name == "[msg]")
			return M
	return 0

/**
 * OLD PROC, DO NOT ADD SHIT TO IT ANYMORE
 * USE `/datum/movespeed_modifier`s instead!
 */
/mob/proc/movement_delay()
	SHOULD_NOT_SLEEP(TRUE)

	if(lying) //Crawling, it's slower
		. += (8 + ((weakened * 3) + (confused * 2)))
	. = get_pulling_movement_delay()

/mob/proc/get_pulling_movement_delay()
	. = 0
	if(istype(pulling, /obj/structure))
		var/obj/structure/P = pulling
		if(P.buckled || locate(/mob) in P.contents)
			. += P.slowdown

/**
 * Handles the biological and general over-time processes of the mob.
 *
 *
 * Arguments:
 * - seconds_per_tick: The amount of time that has elapsed since this last fired
 * - times_fired: The number of times SSmobs has fired
 */
/mob/proc/Life(seconds_per_tick = SSMOBS_DT, times_fired)
	SHOULD_NOT_SLEEP(TRUE)
	SHOULD_CALL_PARENT(TRUE)

	if(LAZYLEN(spell_masters))
		for(var/atom/movable/screen/movable/spell_master/spell_master in spell_masters)
			spell_master.update_spells(0, src)

	if(stat != DEAD)
		return TRUE

/mob/proc/buckled_to()
	// Preliminary work for a future buckle rewrite,
	// where one might be fully restrained (like an elecrical chair), or merely secured (shuttle chair, keeping you safe but not otherwise restrained from acting)
	if(!buckled_to)
		return UNBUCKLED
	return restrained() ? FULLY_BUCKLED : PARTIALLY_BUCKLED

/mob/proc/is_physically_disabled()
	return MOB_IS_INCAPACITATED(INCAPACITATION_DISABLED)

/mob/proc/cannot_stand()
	return MOB_IS_INCAPACITATED(INCAPACITATION_KNOCKDOWN)

// Inside this file, you should use MOB_IS_INCAPACITATED for performance reasons
/mob/proc/incapacitated(var/incapacitation_flags = INCAPACITATION_DEFAULT)

	if ((incapacitation_flags & INCAPACITATION_STUNNED) && stunned)
		return 1

	if ((incapacitation_flags & INCAPACITATION_FORCELYING) && (weakened || resting))
		return 1

	if ((incapacitation_flags & INCAPACITATION_KNOCKOUT) && (stat || paralysis || sleeping || (status_flags & FAKEDEATH)))
		return 1

	if((incapacitation_flags & INCAPACITATION_RESTRAINED) && restrained())
		return 1

	if((incapacitation_flags & (INCAPACITATION_BUCKLED_PARTIALLY|INCAPACITATION_BUCKLED_FULLY)))
		var/buckling = buckled_to()
		if(buckling >= PARTIALLY_BUCKLED && (incapacitation_flags & INCAPACITATION_BUCKLED_PARTIALLY))
			return 1
		if(buckling == FULLY_BUCKLED && (incapacitation_flags & INCAPACITATION_BUCKLED_FULLY))
			return 1

	return 0

/mob/proc/restrained()
	return

/mob/proc/reset_view(atom/A)
	if (client)
		A = A ? A : eyeobj
		if (istype(A, /atom/movable))
			client.perspective = EYE_PERSPECTIVE
			client.eye = A
		else
			if (isturf(loc))
				client.eye = client.mob
				client.perspective = MOB_PERSPECTIVE
			else
				client.perspective = EYE_PERSPECTIVE
				client.eye = loc
	return


/mob/proc/show_inv(mob/user)
	user.set_machine(src)
	var/dat = {"
	<BR><B>Head(Mask):</B> <A href='byond://?src=[REF(src)];item=mask'>[(wear_mask ? wear_mask : "Nothing")]</A>
	<BR><B>Left Hand:</B> <A href='byond://?src=[REF(src)];item=l_hand'>[(l_hand ? l_hand  : "Nothing")]</A>
	<BR><B>Right Hand:</B> <A href='byond://?src=[REF(src)];item=r_hand'>[(r_hand ? r_hand : "Nothing")]</A>
	<BR><B>Back:</B> <A href='byond://?src=[REF(src)];item=back'>[(back ? back : "Nothing")]</A> [((istype(wear_mask, /obj/item/clothing/mask) && istype(back, /obj/item/tank) && !( internal )) ? " <A href='byond://?src=[REF(src)];item=internal'>Set Internal</A>" : "")]
	<BR>[(internal ? "<A href='byond://?src=[REF(src)];item=internal'>Remove Internal</A>" : "")]
	<BR><A href='byond://?src=[REF(src)];item=pockets'>Empty Pockets</A>
	<BR><A href='byond://?src=[REF(user)];refresh=1'>Refresh</A>
	<BR><A href='byond://?src=[REF(user)];mach_close=mob[name]'>Close</A>
	<BR>"}

	var/datum/browser/mob_win = new(user, "mob[name]", capitalize_first_letters(name))
	mob_win.set_content(dat)
	mob_win.open()

//mob verbs are faster than object verbs. See http://www.byond.com/forum/?post=1326139&page=2#comment8198716 for why this isn't atom/verb/examine()
/mob/verb/ExaminateVerb(atom/A as mob|obj|turf in view())
	set name = "Examine"
	set category = "IC"

	//examinate(usr, A)
	DEFAULT_QUEUE_OR_CALL_VERB(VERB_CALLBACK(src, GLOBAL_PROC_REF(examinate), src, A))

/mob/proc/can_examine()
	if(client?.eye == src)
		return TRUE
	return FALSE

/mob/living/silicon/pai/can_examine()
	. = ..()
	if(!.)
		var/atom/our_holder = recursive_loc_turf_check(src, 5)
		if(isturf(our_holder.loc)) // Are we folded on the ground?
			return TRUE

/mob/living/simple_animal/borer/can_examine()
	. = ..()
	if(!. && iscarbon(loc) && isturf(loc.loc)) // We're inside someone, let us examine still.
		return TRUE

/mob/var/obj/effect/decal/point/pointing_effect = null//Spam control, can only point when the previous pointer qdels

/mob/verb/pointed(atom/A as mob|obj|turf in view())
	set name = "Point To"
	set category = "Object"

	DEFAULT_QUEUE_OR_CALL_VERB(VERB_CALLBACK(src, PROC_REF(_pointed), A))

/// possibly delayed verb that finishes the pointing process starting in [/mob/verb/pointed()].
/// either called immediately or in the tick after pointed() was called, as per the [DEFAULT_QUEUE_OR_CALL_VERB()] macro
/mob/proc/_pointed(atom/pointing_at)

	if(!isturf(src.loc) || !(pointing_at in range(world.view, get_turf(src))))
		return FALSE
	if(TIMER_COOLDOWN_RUNNING(src, "point_verb_emote_cooldown"))
		return FALSE
	else
		TIMER_COOLDOWN_START(src, "point_verb_emote_cooldown", 2.5 SECONDS)

	face_atom(pointing_at)
	if(isturf(pointing_at))
		if(pointing_effect)
			end_pointing_effect()
		pointing_effect = new /obj/effect/decal/point(pointing_at)
		pointing_effect.set_invisibility(invisibility)
		addtimer(CALLBACK(src, PROC_REF(end_pointing_effect), pointing_effect), 2 SECONDS)
	else if(!invisibility)
		var/atom/movable/M = pointing_at
		M.add_point_filter()
		M.handle_pointed_at(src)
	SEND_SIGNAL(src, COMSIG_MOB_POINT, pointing_at)
	return TRUE

/mob/proc/end_pointing_effect()
	QDEL_NULL(pointing_effect)

/mob/verb/mode()
	set name = "Activate Held Object"
	set category = "Object"
	set src = usr

	DEFAULT_QUEUE_OR_CALL_VERB(VERB_CALLBACK(src, PROC_REF(execute_mode)))

///proc version to finish /mob/verb/mode() execution. used in case the proc needs to be queued for the tick after its first called
/mob/proc/execute_mode()
	if(hand)
		var/obj/item/W = l_hand
		if (W)
			W.attack_self(src)
			update_inv_l_hand()
		else
			attack_empty_hand(BP_L_HAND)
	else
		var/obj/item/W = r_hand
		if (W)
			W.attack_self(src)
			update_inv_r_hand()
		else
			attack_empty_hand(BP_R_HAND)

/mob/verb/memory()
	set name = "Notes"
	set category = "IC"
	if(mind)
		mind.show_memory(src)
	else
		to_chat(src, "The game appears to have misplaced your mind datum, so we can't show you your notes.")

/mob/verb/add_memory(msg as message)
	set name = "Add Note"
	set category = "IC"

	if (!mind)
		to_chat(src, "The game appears to have misplaced your mind datum, so we can't show you your notes.")
		return

	if (length(mind.memory) >= MAX_PAPER_MESSAGE_LEN)
		to_chat(src, SPAN_DANGER("You have exceeded the alotted text size for memories."))
		return

	msg = sanitize(msg)

	if (length(mind.memory + msg) >= MAX_PAPER_MESSAGE_LEN)
		to_chat(src, SPAN_DANGER("Your input would exceed the alotted text size for memories. Try again with a shorter message."))
		return

	mind.store_memory(msg)

/mob/proc/update_flavor_text()
	set src in usr
	if(usr != src)
		to_chat(usr, "No.")
	var/msg = sanitize(input(usr,"Set the flavor text in your 'examine' verb. Can also be used for OOC notes about your character.","Flavor Text",html_decode(flavor_text)) as message|null, extra = 0)

	if(msg != null)
		flavor_text = msg

/mob/proc/warn_flavor_changed()
	if(flavor_text && flavor_text != "") // don't spam people that don't use it!
		to_chat(src, "<h2 class='alert'>OOC Warning:</h2>")
		to_chat(src, SPAN_ALERT("Your flavor text is likely out of date! <a href='byond://?src=[REF(src)];flavor_change=1'>Change</a>"))

/mob/proc/print_flavor_text()
	if (flavor_text && flavor_text != "")
		var/msg = replacetext(flavor_text, "\n", " ")
		if(length(msg) <= 40)
			return "<span class='message linkify'>[msg]</span>"
		else
			return "<span class='message linkify'>[copytext_preserve_html(msg, 1, 37)]...</span> <a href='byond://?src=[REF(src)];flavor_more=1'>More...</a>"

/mob/verb/abandon_mob()
	set name = "Respawn"
	set category = "OOC"

	if (!client)
		return//This shouldnt happen

	var/failure = null
	if (!( GLOB.config.abandon_allowed ))
		failure = "Respawn is disabled."
	else if (stat != DEAD)
		failure = "You must be dead to use this!"
	else if (SSticker.mode && SSticker.mode.deny_respawn)
		failure = "Respawn is disabled for this roundtype."
	else if(!MayRespawn(1, CREW))
		failure = ""

	if(!isnull(failure))
		if(check_rights(R_ADMIN, show_msg = FALSE))
			if(failure == "")
				failure = "You are not allowed to respawn."
			if(alert(failure + " Override?", "Respawn not allowed", "Yes", "Cancel") != "Yes")
				return
			log_admin("[key_name(usr)] bypassed respawn restrictions (they failed with message \"[failure]\").")
		else
			if(failure != "")
				to_chat(usr, SPAN_DANGER(failure))
			return

	to_chat(usr, "You can respawn now, enjoy your new life!")
	log_game("[usr.name]/[usr.key] used abandon mob.")
	to_chat(usr, SPAN_NOTICE("<B>Make sure to play a different character, and please roleplay correctly!</B>"))

	client?.screen.Cut()
	if(!client)
		log_game("[usr.key] AM failed due to disconnect.")
		return

	announce_ghost_joinleave(client, 0)

	var/mob/abstract/new_player/M = new /mob/abstract/new_player()

	if(!client)
		log_game("[usr.key] AM failed due to disconnect.")
		qdel(M)
		return

	M.key = key
	if(M.mind)
		M.mind.reset()
	M.client.init_verbs()
	return

/client/verb/changes()
	set name = "Changelog"
	set category = "OOC"
	if(!GLOB.changelog_tgui)
		GLOB.changelog_tgui = new /datum/changelog()

	GLOB.changelog_tgui.ui_interact(mob)
	if(prefs.lastchangelog != GLOB.changelog_hash)
		prefs.lastchangelog = GLOB.changelog_hash
		prefs.save_preferences()
		winset(src, "infowindow.changelog", "font-style=;")

/mob/verb/observe()
	set name = "Observe"
	set category = "OOC"
	var/is_admin = 0

	if(client.holder && (client.holder.rights & R_ADMIN))
		is_admin = 1
	else if(stat != DEAD || istype(src, /mob/abstract/new_player))
		to_chat(usr, SPAN_NOTICE("You must be observing to use this!"))
		return

	if(is_admin && stat == DEAD)
		is_admin = 0

	var/list/names = list()
	var/list/namecounts = list()
	var/list/creatures = list()

	for(var/obj/O in world)				//EWWWWWWWWWWWWWWWWWWWWWWWW ~needs to be optimised
		if(!O.loc)
			continue
		if(istype(O, /obj/item/disk/nuclear))
			var/name = "Nuclear Disk"
			if (names.Find(name))
				namecounts[name]++
				name = "[name] ([namecounts[name]])"
			else
				names.Add(name)
				namecounts[name] = 1
			creatures[name] = O

		if(istype(O, /obj/singularity))
			var/name = "Singularity"
			if (names.Find(name))
				namecounts[name]++
				name = "[name] ([namecounts[name]])"
			else
				names.Add(name)
				namecounts[name] = 1
			creatures[name] = O

		if(istype(O, /obj/machinery/bot))
			var/name = "BOT: [O.name]"
			if (names.Find(name))
				namecounts[name]++
				name = "[name] ([namecounts[name]])"
			else
				names.Add(name)
				namecounts[name] = 1
			creatures[name] = O


	for(var/mob/M in sortAtom(GLOB.mob_list))
		var/name = M.name
		if (names.Find(name))
			namecounts[name]++
			name = "[name] ([namecounts[name]])"
		else
			names.Add(name)
			namecounts[name] = 1

		creatures[name] = M


	client.perspective = EYE_PERSPECTIVE

	var/eye_name = null

	var/ok = "[is_admin ? "Admin Observe" : "Observe"]"
	eye_name = input("Please, select a player!", ok, null, null) as null|anything in creatures

	if (!eye_name)
		return

	var/mob/mob_eye = creatures[eye_name]

	if(client && mob_eye)
		client.eye = mob_eye
		if (is_admin)
			client.adminobs = 1
			if(mob_eye == client.mob || client.eye == client.mob)
				client.adminobs = 0

/mob/verb/cancel_camera()
	set name = "Cancel Camera View"
	set category = "OOC"
	unset_machine()
	reset_view(null)

/mob/Topic(href, href_list)
	if(href_list["mach_close"])
		var/t1 = "window=[href_list["mach_close"]]"
		unset_machine()
		src << browse(null, t1)

	if(href_list["flavor_more"])
		var/datum/tgui_module/flavor_text/FT = new /datum/tgui_module/flavor_text(usr, capitalize_first_letters(name), flavor_text)
		FT.ui_interact(usr)

	if(href_list["accent_tag"])
		var/datum/accent/accent = SSrecords.accents[href_list["accent_tag"]]
		if(accent && istype(accent))
			var/datum/browser/accent_win = new(usr, accent.name, capitalize_first_letters(accent.name), 500, 250)
			var/html = "[accent.description]<br>"
			var/datum/asset/spritesheet/S = get_asset_datum(/datum/asset/spritesheet/chat)
			html += "[S.css_tag()]<br>"
			html += {"[S.icon_tag(accent.tag_icon)]<br>"}
			html += "([accent.text_tag])<br>"
			accent_win.set_content(html)
			accent_win.open()

	if(href_list["flavor_change"])
		update_flavor_text()


/mob/proc/pull_damage()
	return 0

/mob/living/carbon/human/pull_damage()
	if(!lying || getBruteLoss() + getFireLoss() < 100)
		return 0
	for(var/thing in organs)
		var/obj/item/organ/external/e = thing
		if(!e || e.is_stump())
			continue
		if((e.status & ORGAN_BROKEN) && !(e.status & ORGAN_SPLINTED))
			return 1
		if(e.status & ORGAN_BLEEDING)
			return 1
	return 0

/mob/mouse_drop_dragged(atom/over, mob/user, src_location, over_location, params)
	..()
	var/mob/M = over
	if(M != user)
		return
	if(user == src)
		return
	if(!Adjacent(user))
		return

	if(istype(M,/mob/living/silicon/ai))
		return

	show_inv(user)


/mob/verb/stop_pulling()

	set name = "Stop Pulling"
	set category = "IC"

	if(pulling)
		pulling.pulledby = null
		pulling = null
		if(pullin)
			pullin.icon_state = "pull0"

/mob/proc/start_pulling(var/atom/movable/AM)

	if ( !AM || !usr || src==AM || !isturf(src.loc) )	//if there's no person pulling OR the person is pulling themself OR the object being pulled is inside something: abort!
		return

	if (AM.anchored)
		if(!AM.buckled_to)
			to_chat(src, SPAN_WARNING("It won't budge!"))
		else
			start_pulling(AM.buckled_to) //Pull the thing they're buckled to instead.
		return

	var/mob/M = null
	if(ismob(AM))
		M = AM
		if(!can_pull_mobs || !can_pull_size)
			to_chat(src, SPAN_WARNING("It won't budge!"))
			return

		if((mob_size < M.mob_size) && (can_pull_mobs != MOB_PULL_LARGER))
			to_chat(src, SPAN_WARNING("It won't budge!"))
			return

		if((mob_size == M.mob_size) && (can_pull_mobs == MOB_PULL_SMALLER))
			to_chat(src, SPAN_WARNING("It won't budge!"))
			return

		if(length(M.grabbed_by))
			to_chat(src, SPAN_WARNING("You can't pull someone being held in a grab!"))
			return

		// If your size is larger than theirs and you have some
		// kind of mob pull value AT ALL, you will be able to pull
		// them, so don't bother checking that explicitly.

		if(!iscarbon(src))
			M.LAssailant = null
		else
			M.LAssailant = WEAKREF(usr)

	else if(isobj(AM))
		var/obj/I = AM
		if(!can_pull_size || can_pull_size < I.w_class)
			to_chat(src, SPAN_WARNING("It won't budge!"))
			return

	if(pulling)
		var/pulling_old = pulling
		stop_pulling()
		// Are we pulling the same thing twice? Just stop pulling.
		if(pulling_old == AM)
			return

	src.pulling = AM
	AM.pulledby = src
	GLOB.move_manager.stop_looping(AM)

	if(pullin)
		pullin.icon_state = "pull1"

	if(ishuman(AM))
		var/mob/living/carbon/human/H = AM
		if(H.lying) // If they're on the ground we're probably dragging their arms to move them
			visible_message(SPAN_WARNING("\The [src] leans down and grips \the [H]'s arms."), SPAN_NOTICE("You lean down and grip \the [H]'s arms."))
		else //Otherwise we're probably just holding their arm to lead them somewhere
			visible_message(SPAN_WARNING("\The [src] grips \the [H]'s arm."), SPAN_NOTICE("You grip \the [H]'s arm."))
		playsound(loc, /singleton/sound_category/grab_sound, 25, FALSE, -1) //Quieter than hugging/grabbing but we still want some audio feedback
		if(H.pull_damage())
			to_chat(src, SPAN_DANGER("Pulling \the [H] in their current condition would probably be a bad idea."))

	//Attempted fix for people flying away through space when cuffed and dragged.
	if(M)
		var/mob/pulled = AM
		pulled.inertia_dir = 0

/mob/proc/can_use_hands()
	return

/mob/proc/is_active()
	return (0 >= usr.stat)

/mob/proc/is_dead()
	return stat == DEAD

/mob/proc/is_mechanical()
	return FALSE

/mob/living/silicon/is_mechanical()
	return TRUE

/mob/living/carbon/human/is_mechanical()
	return species && (species.flags & IS_MECHANICAL)

/mob/proc/is_ready()
	return client && !!mind

/mob/proc/see(message)
	if(!is_active())
		return 0
	to_chat(src, message)
	return 1

/mob/proc/show_viewers(message)
	for(var/mob/M in viewers())
		M.see(message)

// facing verbs
/mob/proc/canface()
	if(!canmove)						return 0
	if(stat)							return 0
	if(anchored)						return 0
	if(transforming)						return 0
	return 1

// Not sure what to call this. Used to check if humans are wearing an AI-controlled exosuit and hence don't need to fall over yet.
/mob/proc/can_stand_overridden()
	return 0

//Updates canmove, lying and icons. Could perhaps do with a rename but I can't think of anything to describe it.
/mob/proc/update_canmove()
	if(in_neck_grab())
		lying = FALSE
		for(var/obj/item/grab/G in grabbed_by)
			if(G.force_down)
				lying = TRUE
				break
	else if(!resting && cannot_stand() && can_stand_overridden())
		lying = FALSE
		lying_is_intentional = FALSE
		canmove = TRUE
	else
		if(istype(buckled_to, /obj/vehicle))
			var/obj/vehicle/V = buckled_to
			if(is_physically_disabled())
				lying = TRUE
				lying_is_intentional = FALSE
				canmove = FALSE
				pixel_y = V.mob_offset_y - 5
			else
				if(buckled_to.buckle_lying != -1) lying = buckled_to.buckle_lying
				lying_is_intentional = FALSE
				canmove = TRUE
				pixel_y = V.mob_offset_y
		else if(buckled_to)
			anchored = TRUE
			canmove = FALSE
			if(isobj(buckled_to))
				if(buckled_to.buckle_lying != -1)
					lying = buckled_to.buckle_lying
					lying_is_intentional = FALSE
				if(buckled_to.buckle_movable)
					anchored = FALSE
					canmove = TRUE
		else if(captured)
			anchored = TRUE
			canmove = FALSE
			lying = FALSE
		else if(m_intent == M_LAY && !incapacitated())
			lying = TRUE
			lying_is_intentional = TRUE
			canmove = TRUE
		else if(sleeping)
			lying = resting || is_dead() || (MOB_IS_INCAPACITATED(INCAPACITATION_KNOCKDOWN) && sleeps_horizontal()) // Vaurca, IPCs and Diona sleep standing up, unless they were already lying down
			lying_is_intentional = FALSE
			canmove = !MOB_IS_INCAPACITATED(INCAPACITATION_KNOCKOUT) && !weakened
		else
			lying = resting || is_dead() || MOB_IS_INCAPACITATED(INCAPACITATION_KNOCKDOWN) && !recently_slept
			lying_is_intentional = FALSE
			canmove = !MOB_IS_INCAPACITATED(INCAPACITATION_KNOCKOUT) && !weakened

	if(lying)
		density = 0
		if(!lying_is_intentional)
			if(l_hand) unEquip(l_hand)
			if(r_hand) unEquip(r_hand)
	else
		density = initial(density)

	for(var/obj/item/grab/G in grabbed_by)
		if(G.wielded)
			canmove = FALSE
			lying = TRUE
			break
		if(G.state >= GRAB_AGGRESSIVE)
			canmove = 0
			break

	//Temporarily moved here from the various life() procs
	//I'm fixing stuff incrementally so this will likely find a better home.
	//It just makes sense for now. ~Carn
	if( update_icon )	//forces a full overlay update
		update_icon = 0
		regenerate_icons()
	else if( lying != lying_prev )
		update_icon()

	return canmove


/mob/proc/sleeps_horizontal()
	return TRUE

/mob/proc/facedir(var/ndir, var/force_change = FALSE)
	if(!canface() || (client && client.moving))
		return 0
	if((facing_dir != ndir) && force_change)
		facing_dir = null
	set_dir(ndir)
	if(buckled_to && buckled_to.buckle_movable)
		buckled_to.set_dir(ndir)
	if (client)//Fixing a ton of runtime errors that came from checking client vars on an NPC
		setMoveCooldown(movement_delay())
	SEND_SIGNAL(src, COMSIG_MOB_FACEDIR, ndir)
	return 1


/mob/verb/eastface()
	set hidden = 1
	return facedir(client.client_dir(EAST))


/mob/verb/westface()
	set hidden = 1
	return facedir(client.client_dir(WEST))


/mob/verb/northface()
	set hidden = 1
	return facedir(client.client_dir(NORTH))


/mob/verb/southface()
	set hidden = 1
	return facedir(client.client_dir(SOUTH))


//This might need a rename but it should replace the can this mob use things check
/mob/proc/IsAdvancedToolUser()
	return 0

/mob/proc/Stun(amount)
	if(status_flags & CANSTUN)
		facing_dir = null
		stunned = max(max(stunned,amount),0) //can't go below 0, getting a low amount of stun doesn't lower your current stun
	return

/mob/proc/SetStunned(amount) //if you REALLY need to set stun to a set amount without the whole "can't go below current stunned"
	if(status_flags & CANSTUN)
		stunned = max(amount,0)
	return

/mob/proc/AdjustStunned(amount)
	if(status_flags & CANSTUN)
		stunned = max(stunned + amount,0)
	return

/mob/proc/Weaken(amount)
	if(status_flags & CANWEAKEN)
		facing_dir = null
		weakened = max(max(weakened,amount),0)
		update_canmove()	//updates lying, canmove and icons
	return

/mob/proc/SetWeakened(amount)
	if(status_flags & CANWEAKEN)
		weakened = max(amount,0)
		update_canmove()	//updates lying, canmove and icons
	return

/mob/proc/AdjustWeakened(amount)
	if(status_flags & CANWEAKEN)
		weakened = max(weakened + amount,0)
		update_canmove()	//updates lying, canmove and icons
	return

/mob/proc/Paralyse(amount)
	if(status_flags & CANPARALYSE)
		facing_dir = null
		paralysis = max(max(paralysis,amount),0)
	return

/mob/proc/SetParalysis(amount)
	if(status_flags & CANPARALYSE)
		paralysis = max(amount,0)
	return

/mob/proc/AdjustParalysis(amount)
	if(status_flags & CANPARALYSE)
		paralysis = max(paralysis + amount,0)
	return

/mob/proc/Sleeping(amount)
	facing_dir = null
	sleeping = max(max(sleeping,amount),0)
	return

/mob/proc/SetSleeping(amount)
	sleeping = max(amount,0)
	return

/mob/proc/AdjustSleeping(amount)
	sleeping = max(sleeping + amount,0)
	if(!sleeping)
		recently_slept = 10
	return

/mob/proc/Resting(amount)
	facing_dir = null
	resting = max(max(resting,amount),0)
	return

/mob/proc/SetResting(amount)
	resting = max(amount,0)
	return

/mob/proc/AdjustResting(amount)
	resting = max(resting + amount,0)
	return

/mob/proc/get_species(var/reference = 0)
	return ""

/mob/proc/get_pressure_weakness()
	return 1

/mob/living/proc/flash_strong_pain()
	return

/mob/living/carbon/human/flash_strong_pain()
	if(can_feel_pain())
		overlay_fullscreen("strong_pain", /atom/movable/screen/fullscreen/strong_pain)
		addtimer(CALLBACK(src, PROC_REF(clear_strong_pain)), 10, TIMER_UNIQUE)

/mob/living/proc/clear_strong_pain()
	clear_fullscreen("strong_pain", 10)

/mob/proc/Jitter(amount)
	jitteriness = max(jitteriness,amount,0)

/mob/proc/get_visible_implants(var/class = 0)
	var/list/visible_implants = list()
	for(var/obj/item/O in embedded)
		if(O.w_class > class)
			visible_implants += O
	return visible_implants

/mob/proc/embedded_needs_process()
	return (embedded.len > 0)

/mob/proc/remove_implant(var/obj/item/implant, var/surgical_removal = FALSE)
	if(!LAZYLEN(get_visible_implants(0))) //Yanking out last object - removing verb.
		remove_verb(src, /mob/proc/yank_out_object)
	for(var/obj/item/O in pinned)
		if(O == implant)
			pinned -= O
		if(!pinned.len)
			anchored = 0
	implant.dropInto(loc)
	implant.add_blood(src)
	implant.update_icon()
	if(istype(implant,/obj/item/implant))
		var/obj/item/implant/imp = implant
		imp.removed()
	. = TRUE

/mob/living/carbon/human/remove_implant(var/obj/item/implant, var/surgical_removal = FALSE, var/obj/item/organ/external/affected)
	if(!affected) //Grab the organ holding the implant.
		for(var/obj/item/organ/external/organ in organs)
			for(var/obj/item/O in organ.implants)
				if(O == implant)
					affected = organ
					break
	if(affected)
		affected.implants -= implant
		if(!surgical_removal)
			shock_stage += 20
			apply_damage((implant.w_class * 7), DAMAGE_BRUTE, affected)
			if(!BP_IS_ROBOTIC(affected) && prob(implant.w_class * 5) && affected.sever_artery()) //I'M SO ANEMIC I COULD JUST -DIE-.
				custom_pain("Something tears wetly in your [affected.name] as [implant] is pulled free!", 50, affecting = affected)
	. = ..()

/mob/proc/yank_out_object()
	set category = "Object"
	set name = "Yank out object"
	set desc = "Remove an embedded item at the cost of bleeding and pain."
	set src in view(1)

	if(!isliving(usr) || !usr.canClick())
		return
	usr.setClickCooldown(20)

	if(usr.stat == 1)
		to_chat(usr, "You are unconscious and cannot do that!")
		return

	if(usr.restrained())
		to_chat(usr, "You are restrained and cannot do that!")
		return

	var/mob/S = src
	var/mob/U = usr
	var/list/valid_objects = list()
	var/self = null

	if(S == U)
		self = 1 // Removing object from yourself.

	valid_objects = get_visible_implants(0)
	if(!valid_objects.len)
		if(self)
			to_chat(src, "You have nothing stuck in your body that is large enough to remove.")
		else
			to_chat(U, "[src] has nothing stuck in their wounds that is large enough to remove.")
		return

	var/obj/item/selection = input("What do you want to yank out?", "Embedded objects") in valid_objects

	if(self)
		to_chat(src, SPAN_WARNING("You attempt to get a good grip on [selection] in your body."))
	else
		to_chat(U, SPAN_WARNING("You attempt to get a good grip on [selection] in [S]'s body."))

	if(!do_after(U, 30))
		return
	if(!selection || !S || !U)
		return

	if(self)
		visible_message(SPAN_WARNING("<b>[src] rips [selection] out of their body!</b>"),
						SPAN_WARNING("<b>You rip [selection] out of your body!</b>"))

	else
		visible_message(SPAN_WARNING("<b>[usr] rips [selection] out of [src]'s body!</b>"),
						SPAN_WARNING("<b>[usr] rips [selection] out of your body!</b>"))

	valid_objects = get_visible_implants(0)

	remove_implant(selection)
	selection.forceMove(get_turf(src))
	if(!(U.l_hand && U.r_hand))
		U.put_in_hands(selection)
	if(ishuman(U))
		var/mob/living/carbon/human/human_user = U
		human_user.bloody_hands(src)
	return 1

/mob/living/proc/handle_statuses()
	handle_stunned()
	handle_weakened()
	handle_stuttering()
	handle_silent()
	handle_drugged()
	handle_slurring()

/mob/living/proc/handle_stunned()
	if(stunned)
		AdjustStunned(-1)
	return stunned

/mob/living/proc/handle_weakened()
	if(weakened)
		weakened = max(weakened-1,0)
	return weakened

/mob/living/proc/handle_stuttering()
	if(stuttering)
		stuttering = max(stuttering-1, 0)
	return stuttering

/mob/living/proc/handle_silent()
	if(silent)
		silent = max(silent-1, 0)
	return silent

/mob/living/proc/handle_drugged()
	if(druggy)
		druggy = max(druggy-1, 0)
	return druggy

/mob/living/proc/handle_slurring()
	if(slurring)
		slurring = max(slurring-1, 0)
	return slurring

/mob/living/proc/handle_paralysed() // Currently only used by simple_animal.dm, treated as a special case in other mobs
	if(paralysis)
		AdjustParalysis(-1)
	return paralysis

//Check for brain worms in head.
/mob/proc/has_brain_worms()

	for(var/I in contents)
		if(istype(I,/mob/living/simple_animal/borer))
			return I

	return null

/mob/proc/Released()
	//This is called when the mob is let out of a holder
	//Override for mob-specific functionality
	return

/mob/verb/face_direction()
	set name = "Face Direction"
	set category = "IC"
	set src = usr

	set_face_dir(dir)

	if(!facing_dir)
		to_chat(usr, "You are now not facing anything.")
	else
		to_chat(usr, "You are now facing [dir2text(facing_dir)].")

/mob/proc/set_face_dir(var/newdir)
	if(newdir == facing_dir)
		facing_dir = null
	else if(newdir)
		set_dir(newdir)
		facing_dir = newdir
	else if(facing_dir)
		facing_dir = null
	else
		set_dir(dir)
		facing_dir = dir

/mob/set_dir(ndir)
	if(facing_dir)
		if(!canface() || lying || buckled_to || restrained())
			facing_dir = null
		else if(dir != facing_dir)
			return ..(facing_dir)
	else
		return ..(ndir)

/mob/forceMove(atom/destination)
	var/old_z = GET_Z(src)

	var/atom/movable/AM
	if (destination != loc && istype(destination, /atom/movable))
		AM = destination
		LAZYADD(AM.contained_mobs, src)
		if(ismob(pulledby))
			var/mob/M = pulledby
			M.stop_pulling()

	if (istype(loc, /atom/movable))
		AM = loc
		LAZYREMOVE(AM.contained_mobs, src)

	. = ..()

	if(. && client)
		client.update_skybox(old_z != GET_Z(src))

/mob/verb/northfaceperm()
	set hidden = 1
	set_face_dir(client.client_dir(NORTH))

/mob/verb/southfaceperm()
	set hidden = 1
	set_face_dir(client.client_dir(SOUTH))

/mob/verb/eastfaceperm()
	set hidden = 1
	set_face_dir(client.client_dir(EAST))

/mob/verb/westfaceperm()
	set hidden = 1
	set_face_dir(client.client_dir(WEST))

/mob/living/verb/unique_action()
	set hidden = 1
	var/obj/item/gun/dakka = get_active_hand()
	if(istype(dakka))
		dakka.unique_action(src)

/mob/living/verb/toggle_firing_mode()
	set hidden = 1
	var/obj/item/gun/dakka = get_active_hand()
	if(istype(dakka))
		dakka.toggle_firing_mode(src)

/mob/proc/adjustEarDamage()
	return

/mob/proc/setEarDamage()
	return

//Throwing stuff

/mob/proc/toggle_throw_mode()
	if (src.in_throw_mode)
		throw_mode_off()
	else
		throw_mode_on()

#define THROW_MODE_ICON 'icons/effects/cursor/throw_mode.dmi'

/mob/proc/throw_mode_off()
	src.in_throw_mode = 0
	if(src.throw_icon) //in case we don't have the HUD and we use the hotkey
		src.throw_icon.icon_state = "act_throw_off"
	if(client?.mouse_pointer_icon == THROW_MODE_ICON)
		client.mouse_pointer_icon = initial(client.mouse_pointer_icon)

/mob/proc/throw_mode_on()
	src.in_throw_mode = 1
	if(src.throw_icon)
		src.throw_icon.icon_state = "act_throw_on"
	if(client?.mouse_pointer_icon == initial(client.mouse_pointer_icon))
		client.mouse_pointer_icon = THROW_MODE_ICON

#undef THROW_MODE_ICON

/mob/proc/is_invisible_to(var/mob/viewer)
	if(isAI(viewer))
		for(var/image/I as anything in SSai_obfuscation.obfuscation_images)
			if(I.loc == src)
				return TRUE
	return (!alpha || !mouse_opacity || viewer.see_invisible < invisibility)

//Admin helpers
/mob/proc/wind_mob(var/mob/admin)
	if (!admin)
		return

	if (!check_rights((R_MOD|R_ADMIN), 1, admin))
		return

	if (alert(admin, "Wind [src]?",,"Yes","No")!="Yes")
		return

	SetWeakened(200)
	visible_message("<span class='info'><b>OOC Information:</b></span> <span class='warning'>[src] has been winded by a member of staff! Please freeze all roleplay involving their character until the matter is resolved! Adminhelp if you have further questions.</span>", SPAN_WARNING("<b>You have been winded by a member of staff! Please stand by until they contact you!</b>"))
	log_admin("[key_name(admin)] winded [key_name(src)]!")
	message_admins("[key_name_admin(admin)] winded [key_name_admin(src)]!", 1)

	feedback_add_details("admin_verb", "WIND")

	return

/mob/proc/unwind_mob(var/mob/admin)
	if (!admin)
		return

	if (!check_rights((R_MOD|R_ADMIN), 1, admin))
		return

	SetWeakened(0)
	visible_message("<span class='info'><b>OOC Information:</b></span> <span class='good'>[src] has been unwinded by a member of staff!</span>", SPAN_WARNING("<b>You have been unwinded by a member of staff!</b>"))
	log_admin("[key_name(admin)] unwinded [key_name(src)]!")
	message_admins("[key_name_admin(admin)] unwinded [key_name_admin(src)]!", 1)

	feedback_add_details("admin_verb", "UNWIND")

	return


/mob/proc/is_clumsy()
	return (mutations & CLUMSY)

//Helper proc for figuring out if the active hand (or given hand) is usable.
/mob/proc/can_use_hand()
	return 1

/client/proc/check_has_body_select()
	return mob && mob.hud_used && istype(mob.zone_sel, /atom/movable/screen/zone_sel)

/client/verb/body_toggle_head()
	set name = "body-toggle-head"
	set hidden = 1
	toggle_zone_sel(list(BP_HEAD,BP_EYES,BP_MOUTH))

/client/verb/body_r_arm()
	set name = "body-r-arm"
	set hidden = 1
	toggle_zone_sel(list(BP_R_ARM,BP_R_HAND))

/client/verb/body_l_arm()
	set name = "body-l-arm"
	set hidden = 1
	toggle_zone_sel(list(BP_L_ARM,BP_L_HAND))

/client/verb/body_chest()
	set name = "body-chest"
	set hidden = 1
	toggle_zone_sel(list(BP_CHEST))

/client/verb/body_groin()
	set name = "body-groin"
	set hidden = 1
	toggle_zone_sel(list(BP_GROIN))

/client/verb/body_r_leg()
	set name = "body-r-leg"
	set hidden = 1
	toggle_zone_sel(list(BP_R_LEG,BP_R_FOOT))

/client/verb/body_l_leg()
	set name = "body-l-leg"
	set hidden = 1
	toggle_zone_sel(list(BP_L_LEG,BP_L_FOOT))

/client/verb/cycle_target_zone()
	set name = "cycle-zone"
	set hidden = 1
	toggle_zone_sel(BP_ALL_LIMBS)

/client/proc/toggle_zone_sel(list/zones)
	if(!check_has_body_select())
		return
	var/atom/movable/screen/zone_sel/selector = mob.zone_sel
	selector.set_selected_zone(next_in_list(mob.zone_sel.selecting,zones), usr)

/mob/proc/get_speech_bubble_state_modifier()
	return "default"

/// Adds this list to the output to the stat browser
/mob/proc/get_status_tab_items()
	. = list("") //we want to offset unique stuff from standard stuff

	SEND_SIGNAL(src, COMSIG_MOB_GET_STATUS_TAB_ITEMS, .)

	if(. && LAZYLEN(spell_list))
		for(var/spell/S in spell_list)
			if((!S.connected_button) || !statpanel(S.panel))
				continue //Not showing the noclothes spell
			switch(S.charge_type)
				if(Sp_RECHARGE)
					. += "[S.panel] [S.charge_counter/10.0]/[S.charge_max/10] [S.connected_button]"
				if(Sp_CHARGES)
					. +="[S.panel] [S.charge_counter]/[S.charge_max] [S.connected_button]"
				if(Sp_HOLDVAR)
					. += "[S.panel] [S.holder_var_type] [S.holder_var_amount] [S.connected_button]"

/// This proc differs slightly from normal TG usage with actions due to how it is repurposed here for hardsuit modules.
/// Take a look at /mob/living/carbon/human/get_actions_for_statpanel().
/mob/proc/get_actions_for_statpanel()
	var/list/data = list()
	return data

/mob/proc/get_weather_protection()
	for(var/obj/item/brolly in get_active_hand())
		if(brolly.gives_weather_protection())
			LAZYADD(., brolly)
	if(!LAZYLEN(.))
		for(var/turf/T as anything in RANGE_TURFS(1, loc))
			for(var/obj/structure/flora/tree in T)
				if(tree.protects_against_weather)
					LAZYADD(., tree)

/mob/living/carbon/human/get_weather_protection()
	. = ..()
	if(!LAZYLEN(.))
		var/obj/item/clothing/head/check_head = get_equipped_item(slot_head_str)
		if(!istype(check_head) || !check_head.protects_against_weather)
			return
		var/obj/item/clothing/suit/check_body = get_equipped_item(slot_wear_suit_str)
		if(!istype(check_body) || !check_body.protects_against_weather)
			return
		for(var/obj/item/clothing/clothing in list(w_uniform, wear_suit, head))
			for(var/obj/item/clothing/accessory/check_accessory in clothing)
				if(!istype(check_accessory) || !check_accessory.protects_against_weather)
					continue
				LAZYADD(., check_accessory)
		LAZYADD(., check_head)
		LAZYADD(., check_body)

/mob/proc/get_weather_exposure()

	// We're inside something else.
	if(!isturf(loc))
		return WEATHER_IGNORE

	var/turf/T = loc
	// We're under a roof or otherwise shouldn't be being rained on.
	if(!T.is_outside())

		// For non-multiz we'll give everyone some nice ambience.
		if(!GET_TURF_ABOVE(T))
			return WEATHER_ROOFED

		// For multi-z, check the actual weather on the turf above.
		// TODO: maybe make this a property of the z-level marker.
		var/turf/above = GET_TURF_ABOVE(T)
		if(above.weather)
			return WEATHER_ROOFED

		// Being more than one level down should exempt us from ambience.
		return WEATHER_IGNORE

	// Nothing's protecting us from the rain here
	var/list/weather_protection = get_weather_protection()
	if(LAZYLEN(weather_protection))
		return WEATHER_PROTECTED

	return WEATHER_EXPOSED

///Apply a proper movespeed modifier based on items we have equipped
/mob/proc/update_equipment_speed_mods()
	var/speedies = 0
	for(var/obj/item/thing in get_equipped_speed_mod_items())
		speedies += (thing.slowdown + thing.slowdown_accessory)

	if(speedies)
		add_or_update_variable_movespeed_modifier(
			/datum/movespeed_modifier/equipment_speedmod,
			multiplicative_slowdown = speedies,
		)
	else
		remove_movespeed_modifier(/datum/movespeed_modifier/equipment_speedmod)

/mob/living/carbon/human/update_equipment_speed_mods()
	//Do not apply the equipment mods if the specie is not affected by them
	if(species?.flags & NO_EQUIP_SPEEDMODS)
		return

	. = ..()


///Get all items in our possession that should affect our movespeed
/mob/proc/get_equipped_speed_mod_items()
	. = list()
	//Aurora BS
	var/list/held_items = list()
	held_items += l_hand
	held_items += r_hand
	//END AURORA BS
	for(var/obj/item/thing in held_items)
		// if(thing.item_flags & SLOWS_WHILE_IN_HAND)
		. += thing

/mob/proc/check_emissive_equipment()
	var/old_zflags = z_flags
	z_flags &= ~ZMM_MANGLE_PLANES
	for(var/atom/movable/AM in get_equipped_items(INCLUDE_POCKETS|INCLUDE_HELD))
		if(AM.z_flags & ZMM_MANGLE_PLANES)
			z_flags |= ZMM_MANGLE_PLANES
			break
	if(old_zflags != z_flags)
		UPDATE_OO_IF_PRESENT

#undef UNBUCKLED
#undef PARTIALLY_BUCKLED
#undef FULLY_BUCKLED
