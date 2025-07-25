
#define evolve_nutrition 5000 //when a nymph gathers this much nutrition, it can evolve into a gestalt

//Diona time variables, these differ slightly between a gestalt and a nymph. All values are times in seconds
/mob/living/carbon/alien/diona
	max_nutrition = 5000
	language = null
	mob_size = 4
	density = 0
	mouth_size = 2 //how large of a creature it can swallow at once, and how big of a bite it can take out of larger things
	eat_types = 0 //This is a bitfield which must be initialised in New(). The valid values for it are in devour.dm
	composition_reagent = /singleton/reagent/nutriment //Dionae are plants, so eating them doesn't give animal protein
	name = "diona nymph"
	desc = "A diona nymph."
	voice_name = "diona nymph"
	accent = ACCENT_ROOTSONG
	adult_form = /mob/living/carbon/human/diona/coeus
	speak_emote = list("chirrups")
	icon = 'icons/mob/diona.dmi'
	icon_state = "nymph"
	death_msg = "expires with a pitiful chirrup..."
	universal_understand = FALSE
	universal_speak = FALSE
	holder_type = /obj/item/holder/diona
	meat_type = /obj/item/reagent_containers/food/snacks/meat/dionanymph
	meat_amount = 2
	maxHealth = 50
	health = 50
	max_stamina = -1
	pass_flags = PASSTABLE

	/// Decorative head flower colour.
	var/flower_color
	/// Decorative head flower sprite.
	var/image/flower_image

	/// Fashionable headwear the nymph may or may not be wearing.
	var/obj/item/clothing/head/hat
	var/datum/reagents/vessel
	/// The time in seconds that this diona can exist in total darkness before its energy runs out.
	var/energy_duration = 144
	/// How long this diona can stay on its feet and keep moving in darkness after energy is gone.
	var/dark_consciousness = 144
	/// How long this diona can survive in darkness after energy is gone, before it dies.
	var/dark_survival = 216
	var/datum/dionastats/DS
	/// If set, then this nymph is inside a gestalt.
	var/mob/living/carbon/gestalt = null
	var/kept_clean = FALSE

	/// Nymph who owns this nymph if split. AI diona nymphs will follow this nymph, and these nymphs can be controlled by the master.
	var/mob/living/carbon/alien/diona/master_nymph
	/// List of all related nymphs.
	var/list/mob/living/carbon/alien/diona/birds_of_feather = list()
	/// If it's an echo nymph, which has unique properties.
	var/echo = FALSE
	/// Whether or not the nymph is detached.
	var/detached = FALSE

	var/datum/reagents/metabolism/ingested

	/// Whether they can attach to a host.
	var/can_attach = TRUE

/mob/living/carbon/alien/diona/Initialize(var/mapload, var/flower_chance = 5)
	if(prob(flower_chance))
		flower_color = get_random_colour(1)
	. = ..(mapload)
	//species = GLOB.all_species[]
	ingested = new /datum/reagents/metabolism(500, src, CHEM_INGEST)
	reagents = ingested
	set_species(SPECIES_DIONA)
	setup_dionastats()
	eat_types |= TYPE_ORGANIC
	nutrition = 0 //We dont start with biomass
	update_verbs()

/mob/living/carbon/alien/diona/Destroy()
	cleanupTransfer()
	QDEL_NULL(ingested)
	QDEL_NULL(vessel)

	QDEL_NULL(DS)
	gestalt = null
	master_nymph = null

	hat = null

	flower_color = null
	flower_image = null
	ClearOverlays()

	. = ..()
	GC_TEMPORARY_HARDDEL

/mob/living/carbon/alien/diona/get_ingested_reagents()
	return ingested

/mob/living/carbon/alien/diona/proc/cleanupTransfer()
	if(!kept_clean)
		for(var/mob/living/carbon/alien/diona/D in birds_of_feather)
			if(D.master_nymph == src)
				D.master_nymph = null
			if(!master_nymph && D != src)
				master_nymph = D
			D.master_nymph = master_nymph
			D.birds_of_feather -= src
		if(master_nymph && mind && !master_nymph.mind)
			mind.transfer_to(master_nymph)
			master_nymph.stunned = 0//Switching mind seems to temporarily stun mobs
			message_admins("\The [src] has died with nymphs remaining; player now controls [key_name_admin(master_nymph)]")
			log_admin("\The [src] has died with nymphs remaining; player now controls [key_name(master_nymph)]")
		master_nymph = null
		birds_of_feather.Cut()

		kept_clean = TRUE


/mob/living/carbon/alien/diona/flowery/Initialize(var/mapload)
	. = ..(mapload, 100)

/mob/living/carbon/alien/diona/movement_delay()
	. = ..()
	switch(m_intent)
		if(M_WALK)
			. += 3
		if(M_RUN)
			species.handle_sprint_cost(src, . + GLOB.config.walk_speed)

/mob/living/carbon/alien/diona/ex_act(severity)
	if(life_tick < 4)
		//If a nymph was just born, then it already took damage from the ex_act on its gestalt
		//So we ignore any farther damage for a couple ticks after its born, to prevent it getting hit twice by the same blast
		return
	else
		..()

/mob/living/carbon/alien/diona/verb/check_light()
	set category = "Abilities"
	set name = "Check Light Level"

	var/light = get_lightlevel_diona(DS)

	if (light <= -0.75)
		to_chat(usr, SPAN_DANGER("It is pitch black here! This is extremely dangerous, we must find light, or death will soon follow!"))
	else if (light <= 0)
		to_chat(usr, SPAN_DANGER("This area is too dim to sustain us for long, we should move closer to the light, or we will shortly be in danger!"))
	else if (light > 0 && light < 1.5)
		to_chat(usr, SPAN_WARNING("The light here can sustain us, barely. It feels cold and distant."))
	else if (light <= 3)
		to_chat(usr, SPAN_NOTICE("This light is comfortable and warm, Quite adequate for our needs."))
	else
		to_chat(usr, SPAN_NOTICE("This warm radiance is bliss. Here we are safe and energised! Stay a while..."))

/mob/living/carbon/alien/diona/start_pulling(var/atom/movable/AM)
	//TODO: Collapse these checks into one proc (see pai and drone)
	if(istype(AM,/obj/item))
		var/obj/item/O = AM
		if(O.w_class > 2)
			to_chat(src, SPAN_WARNING("You are too small to pull that."))
			return
		else
			..()
	else
		to_chat(src, SPAN_WARNING("You are too small to pull that."))
		return

/mob/living/carbon/alien/diona/put_in_hands(obj/item/item_to_equip) // No hands.
	item_to_equip.forceMove(get_turf(src))
	return FALSE

//Functions duplicated from humans, albeit slightly modified
/mob/living/carbon/alien/diona/proc/set_species(var/new_species)
	if(!dna)
		if(!new_species)
			new_species = SPECIES_HUMAN
	else
		if(!new_species)
			new_species = dna.species
		else
			dna.species = new_species

	// No more invisible screaming wheelchairs because of set_species() typos.
	if(!GLOB.all_species[new_species])
		new_species = SPECIES_HUMAN

	if(species)
		if(species.name == new_species)
			return
		if(species.language)
			remove_language(species.language)
		if(species.default_language)
			remove_language(species.default_language)
		// Clear out their species abilities.
		species.remove_inherent_verbs(src)
		holder_type = null

	species = GLOB.all_species[new_species]
	if(species.language)
		add_language(species.language)

	if(species.holder_type)
		holder_type = species.holder_type

	icon_state = lowertext(species.name)
	species.handle_post_spawn(src)

	regenerate_icons()
	make_blood()

	// Rebuild the HUD. If they aren't logged in then login() should reinstantiate it for them.
	if(client?.screen)
		client.screen.len = null
		if(hud_used)
			qdel(hud_used)
		hud_used = new /datum/hud(src)

	return !!species


/mob/living/carbon/alien/diona/proc/make_blood()
	if(vessel)
		return

	vessel = new/datum/reagents(600)
	vessel.my_atom = src

	vessel.add_reagent(/singleton/reagent/blood, 560, temperature = species.body_temperature)
	fixblood()

/mob/living/carbon/alien/diona/proc/fixblood()
	if(!REAGENT_DATA(vessel, /singleton/reagent/blood))
		return
	var/list/new_blood_data = get_blood_data()
	vessel.reagent_data[/singleton/reagent/blood] = vessel.reagent_data[/singleton/reagent/blood] ^ new_blood_data | new_blood_data

/mob/living/carbon/alien/diona/proc/setup_dionastats()
	var/MLS = (1.5 / 2.1) //Maximum energy lost per second, in total darkness
	DS = new/datum/dionastats()
	DS.max_energy = energy_duration * MLS
	DS.stored_energy = (DS.max_energy / 2)
	DS.max_health = maxHealth
	DS.pain_factor = (50 / dark_consciousness) / MLS
	DS.trauma_factor = (DS.max_health / dark_survival) / MLS
	DS.dionatype = DIONA_NYMPH

//This is called periodically to register or remove this nymph's status as a bad organ of the gestalt
//This is used to notify the gestalt when it needs repaired
/mob/living/carbon/alien/diona/proc/check_status_as_organ()
	if(ishuman(gestalt) && !QDELETED(gestalt))
		var/mob/living/carbon/human/H = gestalt
		if(!H.bad_internal_organs)
			return
		if(health < maxHealth)
			if (!(src in H.bad_internal_organs))
				H.bad_internal_organs.Add(src)
		else
			H.bad_internal_organs.Remove(src)


//This function makes sure the nymph has the correct split/merge verbs, depending on whether or not its part of a gestalt
/mob/living/carbon/alien/diona/proc/update_verbs()
	if(gestalt && !detached)
		add_verb(src, /mob/living/carbon/alien/diona/proc/split)
		remove_verb(src, /mob/living/proc/ventcrawl)
		remove_verb(src, /mob/living/proc/hide)
		remove_verb(src, /mob/living/carbon/alien/diona/proc/grow)
		remove_verb(src, /mob/living/carbon/alien/diona/proc/merge)
		remove_verb(src, /mob/living/carbon/proc/absorb_nymph)
		remove_verb(src, /mob/living/carbon/proc/sample)
		remove_verb(src, /mob/living/carbon/alien/diona/proc/remove_hat)
		remove_verb(src, /mob/living/carbon/alien/diona/proc/attach_nymph_limb)
		remove_verb(src, /mob/living/carbon/alien/diona/proc/detach_nymph_limb)
	else
		add_verb(src, /mob/living/carbon/alien/diona/proc/merge)
		add_verb(src, /mob/living/carbon/proc/absorb_nymph)
		add_verb(src, /mob/living/carbon/alien/diona/proc/grow)
		add_verb(src, /mob/living/proc/ventcrawl)
		add_verb(src, /mob/living/proc/hide)
		add_verb(src, /mob/living/carbon/proc/sample)
		add_verb(src, /mob/living/carbon/alien/diona/proc/remove_hat)
		add_verb(src, /mob/living/carbon/alien/diona/proc/attach_nymph_limb)
		add_verb(src, /mob/living/carbon/alien/diona/proc/detach_nymph_limb)
		remove_verb(src, /mob/living/carbon/alien/diona/proc/split) // we want to remove this one

	remove_verb(src, /mob/living/carbon/alien/verb/evolve) //We don't want the old alien evolve verb


/mob/living/carbon/alien/diona/get_status_tab_items()
	. = ..()
	. += "Biomass: [nutrition]/[evolve_nutrition]"
	if(nutrition > evolve_nutrition)
		. += "You have enough biomass to grow!"

//Overriding this function from /mob/living/carbon/alien/life.dm
/mob/living/carbon/alien/diona/handle_regular_status_updates()
	if(status_flags & GODMODE)
		return FALSE

	if(stat == DEAD)
		blinded = TRUE
		silent = FALSE
	else
		updatehealth()
		handle_stunned()
		handle_weakened()
		if(health <= 0)
			cleanupTransfer()
			death()
			blinded = TRUE
			silent = FALSE
			return TRUE

		if(getHalLoss() > 50)
			paralysis = 8

		if(paralysis && paralysis > 0)
			handle_paralysed()
			blinded = TRUE
			set_stat(UNCONSCIOUS)

		if(sleeping)
			if(mind)
				if(mind.active && client)
					sleeping = max(sleeping-1, 0)
			blinded = TRUE
			set_stat(UNCONSCIOUS)
		else if(!resting)
			set_stat(CONSCIOUS)

		// Eyes and blindness.
		if(!has_eyes())
			eye_blind =  TRUE
			blinded =    TRUE
			eye_blurry = TRUE
		else if(eye_blind)
			eye_blind =  max(eye_blind-1,0)
			blinded =    TRUE
		else if(eye_blurry)
			eye_blurry = max(eye_blurry-1, 0)

		//Ears
		if(sdisabilities & DEAF)	//disabled-deaf, doesn't get better on its own
			ear_deaf = max(ear_deaf, 1)
		else if(ear_deaf)			//deafness, heals slowly over time
			ear_deaf = max(ear_deaf-1, 0)
			ear_damage = max(ear_damage-0.05, 0)

		update_icon()

	return TRUE

/mob/living/carbon/alien/diona/proc/wear_hat(var/obj/item/new_hat)
	if(hat)
		return
	hat = new_hat
	new_hat.forceMove(src)
	update_icon()

/mob/living/carbon/alien/diona/MiddleClickOn(var/atom/A)
	if(istype(A, /mob/living/carbon/alien/diona))
		var/mob/living/carbon/alien/diona/D = A
		if(D.master_nymph == src) //if the nymph is subservient to you
			mind.transfer_to(D)
			D.stunned = 0 // Switching mind seems to temporarily stun mobs
			for(var/mob/living/carbon/alien/diona/DIO in src.birds_of_feather) //its me!
				DIO.master_nymph = D
		return TRUE
	. = ..()

/mob/living/carbon/alien/diona/proc/harvest(var/mob/user)
	var/actual_meat_amount = max(1, (meat_amount*0.75))
	if(meat_type && actual_meat_amount > 0 && (stat == DEAD))
		for(var/i = 0; i < actual_meat_amount; i++)
			var/obj/item/meat = new meat_type(get_turf(src))
			if(meat.name == "meat")
				meat.name = "[src.name] [meat.name]"
		if(issmall(src))
			user.visible_message(SPAN_WARNING("[user] chops up \the [src]!"))
			new/obj/effect/decal/cleanable/blood/splatter(get_turf(src))
			qdel(src)
		else
			user.visible_message(SPAN_WARNING("[user] butchers \the [src] messily!"))
			gib()



/mob/living/carbon/alien/diona/adjustBruteLoss(var/amount)
	if (status_flags & GODMODE)
		return
	health = min(health - amount, maxHealth)

/mob/living/carbon/alien/diona/getHalLoss()
	if(status_flags & GODMODE)
		return

	return max((maxHealth - health), 0)
