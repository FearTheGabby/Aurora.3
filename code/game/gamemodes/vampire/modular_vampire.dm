GLOBAL_LIST_INIT(vampirepower_types, (typesof(/datum/power/vampire) - /datum/power/vampire))
GLOBAL_LIST_INIT_TYPED(vampirepowers, /list/datum/power/vampire, list())

/datum/power/vampire
	var/blood_cost = 0

/datum/power/vampire/alertness
	name = "Alertness"
	desc = "Toggle whether you wish for your victims to get paralyzed and forget your deeds."
	helptext = "If active, victims will become paralyzed and forget that you fed on them, instead remembering only a pleasant encounter."
	blood_cost = 0
	verbpath = /mob/living/carbon/human/proc/vampire_alertness

/datum/power/vampire/drain_blood
	name = "Drain Blood"
	desc = "Feed on the blood of a humanoid creature in order to gain further power."
	blood_cost = 0
	verbpath = /mob/living/carbon/human/proc/vampire_drain_blood

/datum/power/vampire/blood_heal
	name = "Blood Heal"
	desc = "At the cost of time and blood, heal any injuries you have sustained."
	helptext = "You must remain uninterrupted in order to heal yourself."
	blood_cost = 0
	verbpath = /mob/living/carbon/human/proc/vampire_bloodheal

/datum/power/vampire/glare
	name = "Glare"
	desc = "Through blood magic, you stun those who are not wearing eye protection and are in your immediate proximity."
	blood_cost = 0
	verbpath = /mob/living/carbon/human/proc/vampire_glare

/datum/power/vampire/hypnotise
	name = "Hypnotise"
	desc = "You overwhelm the mind of your victim, rendering them unable to act for a short period of time."
	helptext = "Requires that both you and your victim stay still for a short duration."
	blood_cost = 0
	verbpath = /mob/living/carbon/human/proc/vampire_hypnotise

/datum/power/vampire/presence
	name = "Presence"
	desc = "Passively influence mortals around you, making them more open towards your presence."
	helptext = "While active, people around will receive social cues to be friendlier towards your character."
	blood_cost = 50
	verbpath = /mob/living/carbon/human/proc/vampire_presence

/datum/power/vampire/touch_of_life
	name = "Touch of Life"
	desc = "You touch the target, transferring healing chemicals to them."
	helptext = "Mechanically, the chemicals transferred is a bit of rezadone, and a tiny amount of oxycomorphine."
	blood_cost = 50
	verbpath = /mob/living/carbon/human/proc/vampire_touch_of_life

/datum/power/vampire/veil_step
	name = "Veil Step"
	desc = "Enter the Veil for a moment, and skip to a shadow of your choosing."
	helptext = "Right click on any tile to activate. If the tile is covered in shadows to any measure, you will teleport there."
	blood_cost = 100
	verbpath = /mob/living/carbon/human/proc/vampire_veilstep

/datum/power/vampire/bats
	name = "Summon Bats"
	desc = "Tear open the Veil for a moment, and summon forth bat familiars to assist you in battle."
	blood_cost = 200
	verbpath = /mob/living/carbon/human/proc/vampire_bats

/datum/power/vampire/screech
	name = "Chiropteran Screech"
	desc = "Emit a powerful screech which shatters glass within a large radius, and stuns those who hear it."
	blood_cost = 200
	verbpath = /mob/living/carbon/human/proc/vampire_screech

/datum/power/vampire/veil_walk
	name = "Veil Walking"
	desc = "You can enter the Veil for a long duration of time, leaving behind only an incorporeal manifestation of yourself."
	helptext = "While veil walking, you can walk through all solid objects and people. Others can see you, but they cannot interact with you. As you stay in this form, you will keep draining your blood. To stop veil walking, activate the power again."
	blood_cost = 250
	verbpath = /mob/living/carbon/human/proc/vampire_veilwalk

/datum/power/vampire/enthrall
	name = "Enthrall"
	desc = "Invoke a bloodbond between yourself and a mortal soul. They will then become your slave, required to execute your every command. They will be dependant on your blood."
	helptext = "This works similarly to feeding: you must have a victim pinned to the ground in order for you to enthrall them."
	blood_cost = 300
	verbpath = /mob/living/carbon/human/proc/vampire_enthrall

/datum/power/vampire/embrace
	name = "The Embrace"
	desc = "Corrupt another innocent soul with the power of the Veil. They will become your kin: a vampire."
	blood_cost = 500
	verbpath = /mob/living/carbon/human/proc/vampire_embrace
