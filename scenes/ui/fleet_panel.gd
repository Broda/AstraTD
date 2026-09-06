extends PanelContainer
## Cards inspect; only BUY NEXT purchases, preserving locked-card keyboard access.
const Data = preload("res://scripts/data/game_data.gd")
const INK = Color("e4eefb")
const MUTED = Color("9fb5cf")
const ACCENT = Color("73e7df")
const PRIORITIES = ["first", "strongest", "nearest", "last", "unslowed"]
const PRIORITY_NAMES = ["Closest to Core", "Strongest", "Nearest", "Last in route", "Needs slowing"]
const ICONS = {"beam":"✦", "range":"◎", "missile":"➤", "cycle":"↻", "pulse":"◉", "drone":"◇", "freeze":"❄", "armor":"◆", "support":"✚"}
var game: Node
var tier_buttons: Array = []
var sell_button: Button
var purchase_button: Button
var close_button: Button
var priority_control: OptionButton
var aim_control: OptionButton
var title_label: Label
var role_label: Label
var stats_label: Label
var sources_label: Label
var commitment_label: Label
var inspection_title: Label
var inspection_effect: Label
var inspection_stats: Label
var inspection_reason: Label
var tree_scroll: ScrollContainer
var tree_content: VBoxContainer
var controls_row: HBoxContainer
var source_scroll: ScrollContainer
var inspection_scroll: ScrollContainer
var cards: Array = []
var path_labels: Array = []
var selected_kind = -1
var selected_identity = 0
var inspected_branch = 0
var inspected_tier = 1
var color = ACCENT
var _styles: Dictionary = {}
var _refreshing = false

func setup(host: Node) -> void:
 game = host
 name = "FleetPanel"
 mouse_filter = Control.MOUSE_FILTER_STOP
 add_theme_stylebox_override("panel", _box(Color("0a1529"), Color("345170"), 12, 1))
 var body = VBoxContainer.new()
 body.add_theme_constant_override("separation", 8)
 _margin(self, 14).add_child(body)
 var header = HBoxContainer.new()
 body.add_child(header)
 var heading = VBoxContainer.new()
 heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 heading.add_theme_constant_override("separation", 1)
 header.add_child(heading)
 title_label = _label(heading, "", 24, INK)
 role_label = _label(heading, "", 13, MUTED)
 close_button = _button(header, "← FLEET", 13)
 close_button.custom_minimum_size = Vector2(94, 40)
 close_button.pressed.connect(func():
  if game.has_method("clear_upgrade_preview"): game.clear_upgrade_preview()
  game.show_catalogue())
 var summary = PanelContainer.new()
 summary.add_theme_stylebox_override("panel", _box(Color("10233a"), Color("28445f"), 8, 1))
 body.add_child(summary)
 var summary_content = VBoxContainer.new()
 summary_content.add_theme_constant_override("separation", 4)
 _margin(summary, 9).add_child(summary_content)
 stats_label = _label(summary_content, "", 14, INK)
 source_scroll = ScrollContainer.new()
 source_scroll.custom_minimum_size.y = 34
 source_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 source_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
 summary_content.add_child(source_scroll)
 sources_label = _label(source_scroll, "", 12, ACCENT)
 sources_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 controls_row = HBoxContainer.new()
 controls_row.add_theme_constant_override("separation", 8)
 body.add_child(controls_row)
 var priority_box = VBoxContainer.new()
 priority_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 controls_row.add_child(priority_box)
 _label(priority_box, "TARGET PRIORITY", 10, MUTED)
 priority_control = OptionButton.new()
 priority_control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 priority_control.custom_minimum_size.y = 32
 priority_control.add_theme_font_size_override("font_size", 13)
 _skin_button(priority_control)
 priority_box.add_child(priority_control)
 priority_control.item_selected.connect(func(index: int):
  if not _refreshing: game.select_target_priority(PRIORITIES[index]))
 var aim_box = VBoxContainer.new()
 aim_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 controls_row.add_child(aim_box)
 _label(aim_box, "NOVA FIRE CONTROL", 10, MUTED)
 aim_control = OptionButton.new()
 aim_control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 aim_control.custom_minimum_size.y = 32
 aim_control.add_theme_font_size_override("font_size", 13)
 aim_control.add_item("Distribute targets")
 aim_control.add_item("Focus fire")
 _skin_button(aim_control)
 aim_box.add_child(aim_control)
 aim_control.item_selected.connect(func(index: int):
  if not _refreshing: game.select_aim_mode("distribute" if index == 0 else "focus"))
 commitment_label = _label(body, "", 12, MUTED)
 tree_scroll = ScrollContainer.new()
 tree_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
 tree_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 tree_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
 tree_scroll.follow_focus = true
 tree_scroll.custom_minimum_size.y = 100
 body.add_child(tree_scroll)
 tree_content = VBoxContainer.new()
 tree_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 tree_content.add_theme_constant_override("separation", 15)
 tree_scroll.add_child(tree_content)
 var inspection = PanelContainer.new()
 inspection.add_theme_stylebox_override("panel", _box(Color("122943"), Color("406481"), 8, 1))
 body.add_child(inspection)
 var inspection_body = VBoxContainer.new()
 inspection_body.add_theme_constant_override("separation", 4)
 _margin(inspection, 9).add_child(inspection_body)
 inspection_title = _label(inspection_body, "", 15, INK)
 inspection_scroll = ScrollContainer.new()
 inspection_scroll.custom_minimum_size.y = 88
 inspection_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 inspection_body.add_child(inspection_scroll)
 var detail_body = VBoxContainer.new()
 detail_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 detail_body.add_theme_constant_override("separation", 4)
 inspection_scroll.add_child(detail_body)
 inspection_effect = _label(detail_body, "", 13, MUTED)
 inspection_stats = _label(detail_body, "", 13, INK)
 inspection_reason = _label(inspection_body, "", 12, ACCENT)
 inspection_body.move_child(inspection_reason, 1)
 purchase_button = _button(inspection_body, "", 13)
 purchase_button.custom_minimum_size.y = 37
 purchase_button.pressed.connect(_purchase_next)
 body.add_child(HSeparator.new())
 var sale_row = HBoxContainer.new()
 body.add_child(sale_row)
 var sale_note = _label(sale_row, "SALVAGE\nRemoves this ship", 11, MUTED)
 sale_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 sell_button = _button(sale_row, "", 13)
 sell_button.custom_minimum_size = Vector2(194, 35)
 sell_button.add_theme_color_override("font_color", Color("ffc18c"))
 sell_button.pressed.connect(func(): game.sell_selected())
 for scroll in [tree_scroll, source_scroll, inspection_scroll]:
  scroll.focus_mode = Control.FOCUS_ALL
  scroll.gui_input.connect(_scroll_keys.bind(scroll))
  scroll.add_theme_stylebox_override("focus", _box(Color(0,0,0,0), ACCENT, 4, 1))
 get_viewport().size_changed.connect(_layout)
 _layout()
 hide()

func _layout() -> void:
 if not is_inside_tree(): return
 var viewport_size = get_viewport_rect().size
 var panel_width = minf(490.0, viewport_size.x - 32.0)
 var panel_height = minf(760.0, viewport_size.y - 140.0)
 position = Vector2(viewport_size.x - panel_width - 22.0, 118.0)
 size = Vector2(panel_width, maxf(440.0, panel_height))

func refresh() -> void:
 if game == null or game.selected < 0 or game.selected >= game.towers.size():
  hide()
  selected_identity = 0
  return
 var tower: Dictionary = game.towers[game.selected]
 var definition: Dictionary = Data.TOWERS[tower.kind]
 var identity = tower.node.get_instance_id()
 var changed = identity != selected_identity
 if int(tower.kind) != selected_kind or tier_buttons.size() != definition.branches.size():
  selected_kind = int(tower.kind)
  color = definition.color
  _build_paths(definition)
 if changed:
  if game.has_method("clear_upgrade_preview"): game.clear_upgrade_preview()
  selected_identity = identity
  inspected_branch = maxi(0, int(tower.branch))
  inspected_tier = mini(3, int(tower.level) + 1)
  tree_scroll.scroll_vertical = 0
  inspection_scroll.scroll_vertical = 0
 _refreshing = true
 title_label.text = "%s  /  TIER %d" % [definition.name, tower.level]
 title_label.add_theme_color_override("font_color", color)
 role_label.text = definition.role
 var stats: Dictionary = game.effective_stats(tower)
 stats_label.text = _current_stats(tower, stats)
 var sources: Array = stats.get("sources", [])
 var source_lines = PackedStringArray()
 for source in sources:
  if source is Dictionary:
   var benefits = PackedStringArray()
   if float(source.get("damage", 0.0)) > 0.0: benefits.append("damage +%d%%" % roundi(source.damage * 100))
   if float(source.get("range", 0.0)) > 0.0: benefits.append("range +%d%%" % roundi(source.range * 100))
   if float(source.get("fire_rate", 0.0)) > 0.0: benefits.append("fire rate +%d%%" % roundi(source.fire_rate * 100))
   source_lines.append("%s: %s" % [source.get("name", "Relay"), ", ".join(benefits)])
  else: source_lines.append(str(source))
 var support_only = bool(stats.get("support_only", tower.kind == 5))
 if support_only:
  sources_label.text = "Strongest bonus per stat • no Relay/self amplification\nGreen: covered • Amber: newly covered after upgrade"
 else:
  sources_label.text = "In range • highest bonus per stat applies:\n" + "\n".join(source_lines) if not source_lines.is_empty() else "No active Relay bonuses"
  if not source_lines.is_empty(): sources_label.text += "\nBase: %.1f hit • %.2f shots/s • %.1f range" % [tower.damage, 1.0 / maxf(.001, tower.rate), tower.range]
 source_scroll.custom_minimum_size.y = 34 if sources_label.text.count("\n") > 0 else 18
 priority_control.get_parent().visible = not support_only
 aim_control.get_parent().visible = tower.kind == 2
 controls_row.visible = not support_only
 var priority_count = 5 if tower.kind == 3 else 4
 if priority_control.item_count != priority_count:
  priority_control.clear()
  for index in range(priority_count): priority_control.add_item(PRIORITY_NAMES[index])
 priority_control.select(clampi(PRIORITIES.find(tower.get("targeting", "first")), 0, priority_count - 1))
 aim_control.select(1 if tower.get("aim_mode", "distribute") == "focus" else 0)
 priority_control.disabled = not game.can_manage()
 aim_control.disabled = not game.can_manage()
 commitment_label.text = "Choose ONE specialization • hover or focus any tier to inspect" if tower.branch < 0 else "COMMITTED: %s • other paths are excluded" % definition.branches[tower.branch]
 for branch in range(tier_buttons.size()):
  path_labels[branch].modulate = Color.WHITE if tower.branch < 0 or tower.branch == branch else Color("8598ac")
  for tier in range(1, 4): _refresh_card(tower, branch, tier)
 sell_button.text = "SALVAGE  +%d cr" % int(tower.invested * .65)
 sell_button.disabled = not game.can_manage()
 _refresh_inspection(tower)
 _refreshing = false
 _layout()

func _build_paths(definition: Dictionary) -> void:
 for child in tree_content.get_children():
  tree_content.remove_child(child)
  child.queue_free()
 tier_buttons.clear()
 cards.clear()
 path_labels.clear()
 for branch in range(definition.branches.size()):
  var path_body = VBoxContainer.new()
  path_body.add_theme_constant_override("separation", 5)
  tree_content.add_child(path_body)
  var first: Dictionary = Data.upgrade_for(definition.id, branch, 1)
  path_labels.append(_label(path_body, "%s  %s" % [_icon_text(first), definition.branches[branch]], 15, color))
  if not str(first.get("purpose", "")).is_empty(): _label(path_body, first.purpose, 12, MUTED)
  var row = HBoxContainer.new()
  row.add_theme_constant_override("separation", 4)
  path_body.add_child(row)
  var buttons: Array = []
  var entries: Array = []
  for tier in range(1, 4):
   var spec: Dictionary = Data.upgrade_for(definition.id, branch, tier)
   var button = _button(row, "", 13)
   button.custom_minimum_size = Vector2(0, 148)
   button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
   button.focus_mode = Control.FOCUS_ALL
   button.mouse_entered.connect(_inspect.bind(branch, tier))
   button.focus_entered.connect(_inspect.bind(branch, tier))
   button.pressed.connect(_inspect.bind(branch, tier))
   var margin = _margin(button, 7)
   margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
   margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
   var content = VBoxContainer.new()
   content.add_theme_constant_override("separation", 4)
   content.mouse_filter = Control.MOUSE_FILTER_IGNORE
   margin.add_child(content)
   var tier_label = _label(content, "TIER %s" % ["I", "II", "III"][tier - 1], 10, color)
   var name_label = _label(content, spec.get("name", definition.branches[branch]), 13, INK)
   var effect = _label(content, spec.get("description", ""), 11, MUTED)
   effect.size_flags_vertical = Control.SIZE_EXPAND_FILL
   var price = _label(content, "%d cr" % spec.get("cost", 0), 12, INK)
   var state = _label(content, "", 10, ACCENT)
   buttons.append(button)
   entries.append({"button":button, "tier":tier_label, "name":name_label, "effect":effect, "price":price, "state":state})
   if tier < 3:
    var connection = _label(row, "›", 16, Color("527590"))
    connection.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
  tier_buttons.append(buttons)
  cards.append(entries)

func _refresh_card(tower: Dictionary, branch: int, tier: int) -> void:
 var entry: Dictionary = cards[branch][tier - 1]
 var spec: Dictionary = Data.upgrade_for(Data.TOWERS[tower.kind].id, branch, tier)
 var owned = tower.branch == branch and tower.level >= tier
 var excluded = tower.branch >= 0 and tower.branch != branch
 var prerequisite = tier > tower.level + 1
 var shortfall = int(game.credits) < int(spec.get("cost", 0))
 var state = "OWNED" if owned else ("EXCLUDED" if excluded else ("NEEDS TIER %s" % ["I", "II", "III"][tier - 2] if prerequisite else ("NEED %d cr" % (int(spec.cost) - int(game.credits)) if shortfall else "AVAILABLE")))
 entry.state.text = state
 entry.state.add_theme_color_override("font_color", color if owned or state == "AVAILABLE" else MUTED)
 entry.button.set_meta("upgrade_state", "owned" if owned else ("exclusive" if excluded else ("prerequisite" if prerequisite else ("unaffordable" if shortfall else "available"))))
 entry.button.set_meta("branch", branch)
 entry.button.set_meta("tier", tier)
 entry.button.tooltip_text = "%s • Tier %d • %d cr\n%s\n%s\nInspect only. Use BUY NEXT to purchase." % [spec.name, tier, spec.cost, spec.description, state]
 var highlighted = branch == inspected_branch and tier == inspected_tier
 var border = color if highlighted else (Color("426376") if owned else Color("2b465f"))
 var background = Color("173a4c") if owned else (Color("101d30") if excluded else Color("142a43"))
 var key = "%s_%s_%s" % [background.to_html(), border.to_html(), highlighted]
 if not _styles.has(key): _styles[key] = _box(background, border, 7, 2 if highlighted else 1)
 entry.button.add_theme_stylebox_override("normal", _styles[key])
 entry.button.modulate = Color("b4c0ce") if excluded else Color.WHITE
 entry.button.disabled = false

func _inspect(branch: int, tier: int) -> void:
 if game == null or game.selected < 0 or game.selected >= game.towers.size(): return
 inspected_branch = branch
 inspected_tier = tier
 inspection_scroll.scroll_vertical = 0
 var tower: Dictionary = game.towers[game.selected]
 for path_index in range(tier_buttons.size()):
  for tier_index in range(1, 4): _refresh_card(tower, path_index, tier_index)
 _refresh_inspection(tower)
 if tier_buttons[branch][tier - 1].has_focus():
  _reveal_card.call_deferred(tier_buttons[branch][tier - 1])
 if game.has_method("preview_support"): game.preview_support(branch, tier)

func _refresh_inspection(tower: Dictionary) -> void:
 var definition: Dictionary = Data.TOWERS[tower.kind]
 inspected_branch = clampi(inspected_branch, 0, definition.branches.size() - 1)
 inspected_tier = clampi(inspected_tier, 1, 3)
 var spec: Dictionary = Data.upgrade_for(definition.id, inspected_branch, inspected_tier)
 var preview: Dictionary = game.preview_upgrade(tower, inspected_branch, inspected_tier)
 var owned = tower.branch == inspected_branch and tower.level >= inspected_tier
 var excluded = tower.branch >= 0 and tower.branch != inspected_branch
 inspection_title.text = "%s  %s · T%d" % [_icon_text(spec), spec.get("name", definition.branches[inspected_branch]), inspected_tier]
 inspection_effect.text = spec.get("description", "")
 var current: Dictionary = preview.get("current", game.effective_stats(tower))
 var after: Dictionary = preview.get("after", current)
 inspection_stats.text = "EXCLUDED • effects cannot be applied to this specialization." if excluded else (_preview_stats(tower, current, after) if not owned else "OWNED • this tier's effect is included in the current stats above.")
 var total_cost = int(preview.get("cost", spec.cost))
 if owned:
  inspection_reason.text = "Installed on this ship."
 elif excluded:
  inspection_reason.text = "EXCLUDED • committed to %s. This path is unavailable on this ship." % definition.branches[tower.branch]
 elif inspected_tier > tower.level + 1:
  inspection_reason.text = "Requires prior tiers • %d cr total remaining investment" % total_cost
 else:
  inspection_reason.text = "%d cr • %s" % [spec.cost, preview.get("reason", "Choosing this path excludes the others." if tower.branch < 0 else "Next tier in your specialization.")]
 var next_tier = int(tower.level) + 1
 var next: Dictionary = Data.upgrade_for(definition.id, inspected_branch, next_tier)
 var affordable = not next.is_empty() and int(game.credits) >= int(next.get("cost", 0))
 purchase_button.disabled = excluded or next_tier > 3 or not affordable or not game.can_manage()
 if excluded:
  purchase_button.text = "PATH EXCLUDED"
 elif next_tier > 3:
  purchase_button.text = "SPECIALIZATION COMPLETE"
 else:
  purchase_button.text = "BUY NEXT: %s  ·  %d cr" % [next.get("name", "Tier %d" % next_tier), next.get("cost", 0)]
  purchase_button.tooltip_text = "Buys tier %d only. %s" % [next_tier, next.get("description", "")]
  if not affordable: purchase_button.text = "NEED %d cr MORE  ·  Tier %d" % [int(next.get("cost", 0)) - int(game.credits), next_tier]
 if not game.can_manage() and not excluded and next_tier <= 3: inspection_reason.text += "\nResume the run to purchase."

func _purchase_next() -> void:
 if purchase_button.disabled or game.selected < 0 or game.selected >= game.towers.size(): return
 var old_level = int(game.towers[game.selected].level)
 game.upgrade(inspected_branch)
 if game.selected >= 0 and game.selected < game.towers.size() and int(game.towers[game.selected].level) > old_level:
  inspected_tier = mini(3, int(game.towers[game.selected].level) + 1)
 refresh()
 if game.has_method("preview_support"): game.preview_support(inspected_branch, inspected_tier)

func _current_stats(tower: Dictionary, stats: Dictionary) -> String:
 if stats.get("support_only", tower.kind == 5):
  return "COVERAGE %.1f  •  %d fleet recipients\nDamage +%d%%  •  Range +%d%%  •  Fire rate +%d%%" % [stats.get("aura_range", stats.get("range", tower.range)), stats.get("affected_count", _affected_count(tower, stats)), roundi(float(stats.get("support_damage", tower.get("support", 0.0))) * 100), roundi(float(stats.get("support_range", 0.0)) * 100), roundi(float(stats.get("support_fire_rate", 0.0)) * 100)]
 var result = "EFFECTIVE  %.1f / hit  •  %.2f shots/s  •  %.1f range" % [stats.get("damage", tower.damage), _frequency(stats), stats.get("range", tower.range)]
 if tower.kind == 2:
  result += "\n%d independent guns • values per gun" % stats.get("gun_count", tower.get("guns", []).size())
  result += "\nPulse: %.1f / enemy · %.2f/s" % [stats.get("pulse_damage", 0.0), 1.0 / maxf(.001, float(stats.get("pulse_rate", 1.0)))] if stats.get("pulse_enabled", false) else "\nPulse offline"
  var count = int(stats.get("drone_count", 0))
  result += "  •  Drones %d" % count
  if count > 0: result += "\nEach drone: %.1f / hit · %.2f shots/s" % [stats.get("drone_damage", 0.0), 1.0 / maxf(.001, float(stats.get("drone_rate", 1.0)))]
 elif tower.kind == 3:
  result += "\nMount arcs ±90° • %s" % tower.get("aiming_status", "thruster-assisted tracking")
  result += "\nSlow %d%% • %.1fs" % [roundi(float(stats.get("slow_power", tower.get("slow_power", .5))) * 100), stats.get("slow_duration", 2.0)]
 elif tower.kind == 4: result += "\nArmor-piercing hits"
 return result

func _preview_stats(tower: Dictionary, before: Dictionary, after: Dictionary) -> String:
 if before.get("support_only", tower.kind == 5):
  return "Coverage %.1f → %.1f • Recipients %d → %d\nFleet buffs: damage %d → %d%% • range %d → %d%%\nFire rate %d → %d%%\nGreen: covered • Amber: newly covered" % [before.get("aura_range", before.get("range", 0.0)), after.get("aura_range", after.get("range", 0.0)), before.get("affected_count", 0), after.get("affected_count", 0), roundi(float(before.get("support_damage", 0.0)) * 100), roundi(float(after.get("support_damage", 0.0)) * 100), roundi(float(before.get("support_range", 0.0)) * 100), roundi(float(after.get("support_range", 0.0)) * 100), roundi(float(before.get("support_fire_rate", 0.0)) * 100), roundi(float(after.get("support_fire_rate", 0.0)) * 100)]
 var result = "Hit %.1f → %.1f • Shots/s %.2f → %.2f\nRange %.1f → %.1f" % [before.get("damage", 0.0), after.get("damage", 0.0), _frequency(before), _frequency(after), before.get("range", 0.0), after.get("range", 0.0)]
 if tower.kind == 2:
  result += "\nGuns: %d • Pulse %s → %s" % [after.get("gun_count", 4), "on" if before.get("pulse_enabled", false) else "off", "on" if after.get("pulse_enabled", false) else "off"]
  if after.get("pulse_enabled", false): result += " (%.1f / enemy)" % after.get("pulse_damage", 0.0)
  result += "\nDrones %d → %d" % [before.get("drone_count", 0), after.get("drone_count", 0)]
  if int(after.get("drone_count", 0)) > 0: result += " • each %.1f hit, %.2f/s" % [after.get("drone_damage", 0.0), 1.0 / maxf(.001, float(after.get("drone_rate", 1.0)))]
 if tower.kind == 3:
  result += "\nSlow %d → %d%% • %.1fs duration" % [roundi(float(before.get("slow_power", tower.get("slow_power", .5))) * 100), roundi(float(after.get("slow_power", tower.get("slow_power", .5))) * 100), after.get("slow_duration", 2.0)]
 return result

func _affected_count(tower: Dictionary, stats: Dictionary) -> int:
 var count = 0
 var radius = float(stats.get("aura_range", stats.get("range", tower.range)))
 for other in game.towers:
  if other.kind != 5 and other.node.position.distance_to(tower.node.position) <= radius: count += 1
 return count

func _frequency(stats: Dictionary) -> float:
 return float(stats.get("attacks_per_second", 1.0 / maxf(.001, float(stats.get("rate", 1.0)))))

func _icon_text(spec: Dictionary) -> String:
 return ICONS.get(str(spec.get("icon", "")), "◆")

func _label(parent: Node, text: String, font_size: int, font_color: Color) -> Label:
 var label = Label.new()
 label.text = text
 label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 label.add_theme_font_size_override("font_size", font_size)
 label.add_theme_color_override("font_color", font_color)
 label.mouse_filter = Control.MOUSE_FILTER_IGNORE
 parent.add_child(label)
 return label

func _margin(parent: Node, padding: int) -> MarginContainer:
 var margin = MarginContainer.new()
 for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, padding)
 parent.add_child(margin)
 return margin

func _button(parent: Node, text: String, font_size: int) -> Button:
 var button = Button.new()
 button.text = text
 button.add_theme_font_size_override("font_size", font_size)
 button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
 _skin_button(button)
 parent.add_child(button)
 return button

func _skin_button(button: BaseButton) -> void:
 button.add_theme_stylebox_override("normal", _box(Color("19354f"), Color("375b79"), 6, 1))
 button.add_theme_stylebox_override("hover", _box(Color("254d6a"), ACCENT, 6, 1))
 button.add_theme_stylebox_override("pressed", _box(Color("315a72"), ACCENT, 6, 2))
 button.add_theme_stylebox_override("disabled", _box(Color("111e30"), Color("293b50"), 6, 1))
 button.add_theme_stylebox_override("focus", _box(Color(0, 0, 0, 0), Color("bcf9ff"), 6, 2))
 button.add_theme_color_override("font_color", INK)
 button.add_theme_color_override("font_disabled_color", MUTED)

func _box(background: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
 var style = StyleBoxFlat.new()
 style.bg_color = background
 style.border_color = border
 style.set_border_width_all(width)
 style.set_corner_radius_all(radius)
 return style

func _scroll_keys(event: InputEvent, scroll: ScrollContainer) -> void:
 if not event is InputEventKey or not event.pressed: return
 match event.keycode:
  KEY_DOWN: scroll.scroll_vertical += 30
  KEY_UP: scroll.scroll_vertical -= 30
  KEY_PAGEDOWN: scroll.scroll_vertical += int(scroll.size.y * .8)
  KEY_PAGEUP: scroll.scroll_vertical -= int(scroll.size.y * .8)
  KEY_HOME: scroll.scroll_vertical = 0
  KEY_END: scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
  _: return
 scroll.accept_event()

func _reveal_card(button: Control) -> void:
 # Wrapped labels trigger several container layout passes after focus changes.
 for _frame in range(2):
  await get_tree().process_frame
  if not is_instance_valid(button) or not tree_scroll.is_ancestor_of(button): return
 if button.has_focus(): tree_scroll.ensure_control_visible(button)
