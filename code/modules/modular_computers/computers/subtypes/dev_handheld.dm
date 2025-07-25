/obj/item/modular_computer/handheld
	name = "tablet computer"
	lexical_name = "tablet"
	desc = "A portable device for your needs on the go."
	icon = 'icons/obj/modular_tablet.dmi'
	icon_state = "tablet"
	icon_state_unpowered = "tablet"
	icon_state_menu = "menu"
	overlay_state = "nothing"
	slot_flags = SLOT_ID | SLOT_BELT
	can_reset = TRUE
	hardware_flag = PROGRAM_TABLET
	max_hardware_size = 1
	w_class = WEIGHT_CLASS_SMALL
	looping_sound = FALSE

/obj/item/modular_computer/handheld/mechanics_hints(mob/user, distance, is_adjacent)
	. += ..()
	. += "To deploy the charging cable on this device, either drag and drop it over a nearby APC, or click on the APC with the computer in hand."

/obj/item/modular_computer/handheld/Initialize()
	. = ..()
	set_icon()

/obj/item/modular_computer/handheld/Destroy()
	. = ..()
	GC_TEMPORARY_HARDDEL

/obj/item/modular_computer/handheld/proc/set_icon()
	icon_state_unpowered = icon_state
	icon_state_broken = icon_state
