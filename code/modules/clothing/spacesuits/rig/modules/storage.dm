/obj/item/rig_module/storage
	name = "mounted storage unit"
	interface_name = "mounted storage unit"
	interface_desc = "A storage unit for storing a precious few items in your hardsuit."
	icon_state = "paper"

	origin_tech = list(TECH_MAGNET = 2, TECH_MATERIAL = 2, TECH_ENGINEERING = 3)
	category = MODULE_GENERAL

	var/obj/item/storage/internal/hardsuit/pockets
	var/storage_slots = null
	var/storage_max_w_class = WEIGHT_CLASS_NORMAL
	var/storage_max_storage_space = 9

/obj/item/rig_module/storage/Initialize()
	. = ..()
	pockets = new /obj/item/storage/internal/hardsuit(src)
	pockets.storage_slots = storage_slots
	pockets.max_w_class = storage_max_w_class
	pockets.max_storage_space = storage_max_storage_space

/obj/item/rig_module/storage/Destroy()
	QDEL_NULL(pockets)

	. = ..()

/obj/item/rig/mouse_drop_dragged(atom/over, mob/user, src_location, over_location, params)
	var/obj/item/rig_module/storage/storage = locate() in installed_modules
	if(storage && !storage.pockets.handle_mousedrop(user, over))
		return
	return ..()

/obj/item/rig/handle_middle_mouse_click(mob/user)
	var/obj/item/rig_module/storage/storage = locate() in installed_modules
	if(storage && Adjacent(user))
		storage.pockets.open(user)
		return TRUE
	return FALSE

/obj/item/rig/hear_talk(mob/M, var/msg, verb, datum/language/speaking)
	var/obj/item/rig_module/storage/storage = locate() in installed_modules
	if(storage)
		storage.pockets.hear_talk(M, msg, verb, speaking)
	return ..()
