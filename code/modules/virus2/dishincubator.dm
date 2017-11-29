/obj/machinery/disease2/incubator/
	name = "Pathogenic incubator"
	density = 1
	anchored = 1
	icon = 'icons/obj/virology.dmi'
	icon_state = "incubator"
	allowed_checks = ALLOWED_CHECK_TOPIC
	var/obj/item/weapon/virusdish/dish
	var/obj/item/weapon/reagent_containers/glass/beaker = null
	var/radiation = 0

	var/on = 0
	var/power = 0

	var/foodsupply = 0
	var/toxins = 0

/obj/machinery/disease2/incubator/attackby(obj/O, mob/user)
	if(istype(O, /obj/item/weapon/reagent_containers/glass) || istype(O,/obj/item/weapon/reagent_containers/syringe))

		if(beaker)
			to_chat(user, "\The [src] is already loaded.")
			return

		beaker = O
		user.drop_item()
		O.loc = src

		user.visible_message("[user] adds \a [O] to \the [src]!", "You add \a [O] to \the [src]!")
		nanomanager.update_uis(src)

		src.attack_hand(user)
		return

	if(istype(O, /obj/item/weapon/virusdish))

		if(dish)
			to_chat(user, "The dish tray is aleady full!")
			return

		dish = O
		user.drop_item()
		O.loc = src

		user.visible_message("[user] adds \a [O] to \the [src]!", "You add \a [O] to \the [src]!")
		nanomanager.update_uis(src)

		src.attack_hand(user)

/obj/machinery/disease2/incubator/ui_interact(mob/user, ui_key = "main", datum/nanoui/ui = null)
	var/data[0]
	data["chemicals_inserted"] = !!beaker
	data["dish_inserted"] = !!dish
	data["food_supply"] = foodsupply
	data["radiation"] = radiation
	data["toxins"] = min(toxins, 100)
	data["on"] = on
	data["system_in_use"] = foodsupply > 0 || radiation > 0 || toxins > 0
	data["chemical_volume"] = beaker ? beaker.reagents.total_volume : 0
	data["max_chemical_volume"] = beaker ? beaker.volume : 1
	data["virus"] = dish ? dish.virus2 : null
	data["growth"] = dish ? min(dish.growth, 100) : 0
	data["infection_rate"] = dish && dish.virus2 ? dish.virus2.infectionchance * 10 : 0
	data["analysed"] = dish && dish.analysed ? 1 : 0
	data["can_breed_virus"] = null
	data["blood_already_infected"] = null

	if (beaker)
		var/datum/reagent/blood/B = locate(/datum/reagent/blood) in beaker.reagents.reagent_list
		data["can_breed_virus"] = dish && dish.virus2 && B

		if (B)
			if (!B.data["virus2"])
				B.data["virus2"] = list()

			var/list/virus = B.data["virus2"]
			for (var/ID in virus)
				data["blood_already_infected"] = virus[ID]

	ui = nanomanager.try_update_ui(user, src, ui_key, ui, data)
	if (!ui)
		ui = new(user, src, ui_key, "dish_incubator.tmpl", src.name, 400, 600)
		ui.set_initial_data(data)
		ui.open()

/obj/machinery/disease2/incubator/process()
	if(dish && on && dish.virus2)
		use_power(50,EQUIP)
		if(!powered(EQUIP))
			on = 0
			icon_state = "incubator"

		if(foodsupply)
			if(dish.growth + 3 >= 100 && dish.growth < 100)
				ping("\The [src] pings, \"Sufficient viral growth density achieved.\"")

			foodsupply -= 1
			dish.growth += 3
			nanomanager.update_uis(src)

		if(radiation)
			if(radiation > 50 & prob(5))
				dish.virus2.majormutate()
				if(dish.info)
					dish.info = "OUTDATED : [dish.info]"
					dish.analysed = 0
				ping("\The [src] pings, \"Mutant viral strain detected.\"")
			else if(prob(5))
				dish.virus2.minormutate()
			radiation -= 1
			nanomanager.update_uis(src)
		if(toxins && prob(5))
			dish.virus2.infectionchance -= 1
			nanomanager.update_uis(src)
		if(toxins > 50)
			dish.growth = 0
			dish.virus2 = null
			nanomanager.update_uis(src)
	else if(!dish)
		on = 0
		icon_state = "incubator"
		nanomanager.update_uis(src)

	if(beaker)
		if(beaker.reagents.get_reagent_amount("virusfood"))
			foodsupply += (min(beaker.reagents.get_reagent_amount("virusfood"), 5))*2
			beaker.reagents.remove_reagent("virusfood", 5)
			nanomanager.update_uis(src)


		if (locate(/datum/reagent/toxin) in beaker.reagents.reagent_list)
			for(var/datum/reagent/toxin/T in beaker.reagents.reagent_list)
				toxins += max(T.toxpwr,1)
				beaker.reagents.remove_reagent(T.id,1)
			nanomanager.update_uis(src)

/obj/machinery/disease2/incubator/Topic(href, href_list)
	var/mob/user = usr
	var/datum/nanoui/ui = nanomanager.get_open_ui(user, src, "main")

	if (href_list["close"])
		user.unset_machine(src)
		ui.close()
		return FALSE

	. = ..()
	if(!.)
		return

	if (href_list["ejectchem"])
		if (beaker)
			beaker.loc = src.loc
			beaker = null
		return TRUE

	if (href_list["power"])
		if (dish)
			on = !on
			icon_state = on ? "incubator_on" : "incubator"
		return TRUE

	if (href_list["ejectdish"])
		if (dish)
			dish.loc = src.loc
			dish = null
		return TRUE

	if (href_list["rad"])
		radiation += 10
		return TRUE

	if (href_list["flush"])
		radiation = 0
		toxins = 0
		foodsupply = 0
		return TRUE

	if (href_list["virus"])
		if(!dish)
			return TRUE

		var/datum/reagent/blood/B = locate(/datum/reagent/blood) in beaker.reagents.reagent_list
		if(!B)
			return TRUE

		if(!B.data["virus2"])
			B.data["virus2"] = list()

		var/list/virus = list("[dish.virus2.uniqueID]" = dish.virus2.getcopy())
		B.data["virus2"] += virus

		ping("\The [src] pings, \"Injection complete.\"")
		return TRUE

	return FALSE
