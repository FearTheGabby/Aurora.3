// Alien larva are quite simple.
/mob/living/carbon/alien/Life(seconds_per_tick, times_fired)
	if (transforming)	return
	if(!loc)			return

	..()

	if (stat != DEAD && can_progress())
		update_progression()

	blinded = null

	//Status updates, death etc.
	update_icon()

/mob/living/carbon/alien/proc/can_progress()
	return 1


/mob/living/carbon/alien/handle_mutations_and_radiation()

	// Currently both Dionaea and larvae like to eat radiation, so I'm defining the
	// rad absorbtion here. This will need to be changed if other baby aliens are added.

	if(!total_radiation)
		return

	var/rads = total_radiation/25
	apply_radiation(rads*-1)
	adjustNutritionLoss(-rads)
	heal_overall_damage(rads,rads)
	adjustOxyLoss(-(rads))
	adjustToxLoss(-(rads))
	return

/mob/living/carbon/alien/handle_regular_status_updates()

	if(status_flags & GODMODE)	return 0

	if(stat == DEAD)
		blinded = 1
		silent = 0
	else
		updatehealth()
		handle_stunned()
		handle_weakened()
		if(health <= 0)
			death()
			blinded = 1
			silent = 0
			return 1

		if(paralysis && paralysis > 0)
			handle_paralysed()
			blinded = 1
			set_stat(UNCONSCIOUS)
			if(getHalLoss() > 0)
				adjustHalLoss(-3)

		if(sleeping)
			adjustHalLoss(-3)
			if (mind)
				if(mind.active && client != null)
					sleeping = max(sleeping-1, 0)
			blinded = 1
			set_stat(UNCONSCIOUS)
		else if(resting)
			if(getHalLoss() > 0)
				adjustHalLoss(-3)

		else
			set_stat(CONSCIOUS)
			if(getHalLoss() > 0)
				adjustHalLoss(-1)

		// Eyes and blindness.
		if(!has_eyes())
			eye_blind =  1
			blinded =    1
			eye_blurry = 1
		else if(eye_blind)
			eye_blind =  max(eye_blind-1,0)
			blinded =    1
		else if(eye_blurry)
			eye_blurry = max(eye_blurry-1, 0)

		update_icon()

	return 1

/mob/living/carbon/alien/handle_regular_hud_updates()
	if(!..())
		return // Returns if no client.

	if(stat == DEAD || (mutations & XRAY))
		set_sight(sight|SEE_TURFS|SEE_MOBS|SEE_OBJS)
		set_see_invisible(SEE_INVISIBLE_LEVEL_TWO)
	else if(stat != DEAD && is_ventcrawling == FALSE)
		if(species && species.vision_flags)
			sight = species.vision_flags
		else
			set_sight(sight&(~SEE_TURFS)&(~SEE_MOBS)&(~SEE_OBJS))
		set_see_invisible(SEE_INVISIBLE_LIVING)

	if (healths)
		if (stat != DEAD)
			switch((health - getHalLoss()) / maxHealth * 100) // Halloss should be factored in here for displaying
				if(100 to INFINITY)
					healths.icon_state = "health0"
				if(80 to 100)
					healths.icon_state = "health1"
				if(60 to 80)
					healths.icon_state = "health2"
				if(40 to 60)
					healths.icon_state = "health3"
				if(20 to 40)
					healths.icon_state = "health4"
				if(0 to 20)
					healths.icon_state = "health5"
				else
					healths.icon_state = "health6"
		else
			healths.icon_state = "health7"

	client.screen.Remove(GLOB.global_hud.blurry, GLOB.global_hud.druggy, GLOB.global_hud.vimpaired)

	if(stat != DEAD)
		if(blinded)
			overlay_fullscreen("blind", /atom/movable/screen/fullscreen/blind)
		else
			clear_fullscreen("blind")
			set_fullscreen(disabilities & NEARSIGHTED, "impaired", /atom/movable/screen/fullscreen/impaired, 1)
			set_fullscreen(eye_blurry, "blurry", /atom/movable/screen/fullscreen/blurry)
		if(machine)
			if (machine.check_eye(src) < 0)
				reset_view(null)
		else
			if(client && !client.adminobs)
				reset_view(null)

	return 1

/mob/living/carbon/alien/handle_environment(var/datum/gas_mixture/environment)
	..()
	// Both alien subtypes survive in vaccum and suffer in high temperatures,
	// so I'll just define this once, for both (see radiation comment above)
	if(!environment) return

	if(environment.temperature > (T0C+66))
		adjustFireLoss((environment.temperature - (T0C+66))/5) // Might be too high, check in testing.
		if (fire) fire.icon_state = "fire2"
		if(prob(20))
			to_chat(src, SPAN_DANGER("You feel a searing heat!"))
	else
		if (fire) fire.icon_state = "fire0"

/mob/living/carbon/alien/handle_fire()
	if(..())
		return
	bodytemperature += BODYTEMP_HEATING_MAX //If you're on fire, you heat up!
	return
