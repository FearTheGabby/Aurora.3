/client/proc/aooc(msg as text)
	set category = "OOC"
	set name = "AOOC"
	set desc = "Antagonist OOC"

	if (istype(src.mob, /mob/abstract/ghost/observer) && !check_rights(R_ADMIN|R_MOD|R_CCIAA, 0))
		to_chat(src, SPAN_WARNING("You cannot use AOOC while ghosting/observing!"))
		return

	if (handle_spam_prevention(msg, MUTE_AOOC))
		return

	msg = sanitize(msg)
	if(!msg)
		return

	var/display_name = src.key
	if (holder)
		display_name = "[display_name]([holder.rank])"
		if (holder.fakekey)
			display_name = holder.fakekey

	for(var/mob/M in GLOB.mob_list)
		if (check_rights(R_ADMIN|R_MOD|R_CCIAA, 0, M) && M.client.aooc_mute_holder_check() == FALSE)
			to_chat(M, "<span class='aooc'>" + create_text_tag("A-OOC", M.client) + " <EM>[get_options_bar(src, 0, 1, 1)](<A href='byond://?_src_=holder;adminplayerobservejump=[REF(src.mob)]'>JMP</A>):</EM> <span class='message linkify'>[msg]</span></span>")
		else if (M.mind && M.mind.special_role && M.client && player_is_antag(M.mind))
			to_chat(M, "<span class='aooc'>" + create_text_tag("A-OOC", M.client) + " <EM>[display_name]:</EM> <span class='message linkify'>[msg]</span></span>")

	log_ooc("(ANTAG) [key] : [msg]")

// Checks if a newly joined player is an antag, and adds the AOOC verb if they are.
// Because they're tied to client objects, this gets removed every time you disconnect.
/client/proc/add_aooc_if_necessary()
	if (!src.mob || !src.mob.mind)
		return

	if (player_is_antag(src.mob.mind))
		add_verb(src, /client/proc/aooc)
