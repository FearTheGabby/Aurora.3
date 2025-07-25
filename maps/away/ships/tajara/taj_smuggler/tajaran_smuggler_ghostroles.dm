//tajaran smuggler ship

/datum/ghostspawner/human/tajaran_smuggler
	short_name = "tajaran_smuggler"
	name = "Tajaran Smuggler"
	desc = "Crew a Tajaran smuggling ship. Try to sell some of your illegally-acquired goods and make a profit."
	tags = list("External")

	spawnpoints = list("tajaran_smuggler")
	max_count = 2

	outfit = /obj/outfit/admin/tajaran_smuggler

	possible_species = list(SPECIES_TAJARA,SPECIES_TAJARA_MSAI,SPECIES_TAJARA_ZHAN)
	allow_appearance_change = APPEARANCE_PLASTICSURGERY

	uses_species_whitelist = FALSE

	assigned_role = "Independent Spacer"
	special_role = "Tajaran Smuggler"
	respawn_flag = null

/obj/outfit/admin/tajaran_smuggler
	name = "Tajaran Smuggler"

	uniform = list(
				/obj/item/clothing/under/tajaran,
				/obj/item/clothing/under/tajaran/summer,
				/obj/item/clothing/pants/tajaran,
				/obj/item/clothing/under/syndicate/tracksuit,
				/obj/item/clothing/under/tajaran/mechanic

	)

	head = list(/obj/item/clothing/head/fedora/grey,
				/obj/item/clothing/head/bucket,
				/obj/item/clothing/head/that,
				/obj/item/clothing/head/tajaran/fur,
				/obj/item/clothing/head/bandana/red,
				/obj/item/clothing/head/bandana/colorable/random
	)

	shoes = list(
				/obj/item/clothing/shoes/tajara/footwraps,
				/obj/item/clothing/shoes/jackboots/tajara,
				/obj/item/clothing/shoes/workboots/tajara,
				/obj/item/clothing/shoes/workboots/tajara/adhomian_boots
	)

	back = list(
		/obj/item/storage/backpack,
		/obj/item/storage/backpack/satchel/leather,
		/obj/item/storage/backpack/satchel,
		/obj/item/storage/backpack/duffel
	)

	id = /obj/item/card/id

	l_ear = /obj/item/device/radio/headset/ship

	backpack_contents = list(/obj/item/storage/box/survival = 1, /obj/item/storage/wallet/random = 1)
	species_shoes = list(
		SPECIES_UNATHI = /obj/item/clothing/shoes/workboots/toeless,
		SPECIES_TAJARA = /obj/item/clothing/shoes/workboots/toeless,
		SPECIES_TAJARA_MSAI = /obj/item/clothing/shoes/workboots/toeless,
		SPECIES_TAJARA_ZHAN = /obj/item/clothing/shoes/workboots/toeless
	)

/obj/outfit/admin/tajaran_smuggler/get_id_access()
	return list(ACCESS_EXTERNAL_AIRLOCKS)


/datum/ghostspawner/human/tajaran_smuggler/captain
	short_name = "tajaran_smuggler_captain"
	name = "Tajaran Smuggler Captain"
	desc = "Captain the Adhomian smuggling ship. Try to make a profit from selling your goods."

	spawnpoints = list("tajaran_smuggler_captain")
	max_count = 1

	outfit = /obj/outfit/admin/freighter_crew/captain

	uses_species_whitelist = TRUE

	assigned_role = "Independent Captain"
	special_role = "Tajaran Smuggler Captain"


/obj/outfit/admin/tajaran_smuggler/captain
	name = "Tajaran Smuggler Captain"

	uniform = /obj/item/clothing/under/syndicate
	head = /obj/item/clothing/head/tanker
