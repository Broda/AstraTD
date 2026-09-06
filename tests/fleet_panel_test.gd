extends SceneTree
## Real-game inspector regression. Run with --script ... -- --fleet-panel-test.
const Data = preload("res://scripts/data/game_data.gd")
var failures = 0
var game: Node
var panel: Control

func _initialize() -> void:
 run.call_deferred()

func check(condition: bool, message: String) -> void:
 if not condition:
  failures += 1
  push_error(message)

func settle() -> void:
 for _frame in range(5): await process_frame

func run() -> void:
 game = load("res://scenes/gameplay/main.tscn").instantiate()
 root.add_child(game)
 await settle()
 game.set_process(false)
 game.credits = 9000
 panel = game.get("fleet_panel")
 if panel == null:
  panel = load("res://scenes/ui/fleet_panel.gd").new()
  game.ui.add_child(panel)
  panel.setup(game)
 game.create_tower(2, Vector3(-10, 0, -5))
 game.selected = 0
 game.refresh_ui()
 panel.refresh()
 panel.show()
 await settle()
 check(panel.tier_buttons.size() == 3, "Nova must expose all three named paths.")
 var future: Button = panel.tier_buttons[2][2]
 future.grab_focus()
 await settle()
 assert_card_visible()
 check(panel.inspected_branch == 2 and panel.inspected_tier == 3, "Keyboard focus must inspect future drone tier.")
 var focused_text: String = panel.inspection_stats.text
 future.mouse_entered.emit()
 check(panel.inspection_stats.text == focused_text, "Hover and keyboard focus must expose identical preview details.")
 panel.close_button.grab_focus()
 var reached_future = false
 for _step in range(20):
  await key_event(KEY_TAB)
  if root.gui_get_focus_owner() == future:
   reached_future = true
   break
 check(reached_future, "Tab must reach an inspectable future tier through panel controls.")
 await key_event(KEY_TAB, true)
 check(root.gui_get_focus_owner() != future, "Shift+Tab must move backwards from a tier.")
 await key_event(KEY_TAB)
 check(root.gui_get_focus_owner() == future, "Tab must restore the next tier in the focus order.")
 assert_card_visible()
 var before_enter = game.credits
 await key_event(KEY_ENTER)
 check(game.credits == before_enter and game.towers[0].level == 0, "Enter on a future tier must inspect without purchasing.")
 var credits = game.credits
 future.pressed.emit()
 check(game.credits == credits and game.towers[0].level == 0, "Pressing a future card must only inspect it.")
 check("Drones 0 → 3" in focused_text and "investment" in panel.inspection_reason.text, "Future tier must show prerequisite-inclusive drone count and investment.")
 var identity = future.get_instance_id()
 for _i in range(20): panel.refresh()
 check(panel.tier_buttons[2][2].get_instance_id() == identity and root.gui_get_focus_owner() == future, "Repeated refresh must preserve card identity and keyboard focus.")
 panel.purchase_button.pressed.emit()
 check(game.towers[0].level == 1 and game.towers[0].branch == 2 and game.towers[0].drone_count == 1, "BUY NEXT must purchase only tier I while tier III was inspected.")
 panel.tier_buttons[2][0].grab_focus()
 await settle()
 check("OWNED" in panel.inspection_stats.text, "Owned cards must show installed effects, not another multiplication.")
 panel.tier_buttons[0][2].grab_focus()
 await settle()
 check(not panel.tier_buttons[0][2].disabled and panel.purchase_button.disabled and "EXCLUDED" in panel.inspection_reason.text, "Excluded paths must remain inspectable while purchase is prevented.")
 panel.tier_buttons[2][1].grab_focus()
 game.credits = 0
 panel.refresh()
 check(not panel.tier_buttons[2][1].disabled and panel.purchase_button.disabled, "Unaffordable cards must remain keyboard inspectable.")
 game.credits = 9000
 panel.refresh()
 panel.priority_control.select(1)
 panel.priority_control.item_selected.emit(1)
 check(game.towers[0].targeting == "strongest", "Priority control must update the actual selected ship.")
 panel.aim_control.select(1)
 panel.aim_control.item_selected.emit(1)
 check(game.towers[0].aim_mode == "focus", "Nova fire-control selection must update the actual ship.")
 for kind in range(Data.TOWERS.size()):
  game.create_tower(kind, Vector3(-8 + kind * 2, 0, -5))
  game.selected = game.towers.size() - 1
  panel.refresh()
  panel.show()
  await settle()
  check(panel.size.x <= 490.1 and panel.size.y <= 760.1, "Inspector must fit its 490×760 area for " + Data.TOWERS[kind].name)
  check(panel.position.y + panel.size.y <= root.get_visible_rect().size.y, "Inspector must remain within design viewport.")
  for branch in range(panel.tier_buttons.size()):
   for tier in range(3):
    var card: Button = panel.tier_buttons[branch][tier]
    check(card.size.x >= 100, "Tier card must have usable reading width.")
    var entries: Dictionary = panel.cards[branch][tier]
    check(entries.state.get_global_rect().end.y <= card.get_global_rect().end.y + 1.0, "Card text must fit inside its button: " + entries.name.text)
  if kind == 5:
   check(panel.tier_buttons.size() == 3 and "COVERAGE" in panel.stats_label.text, "Relay must show three buff paths and separate coverage.")
   check(not panel.controls_row.visible and "Strongest bonus per stat" in panel.sources_label.text, "Support-only Relay must explain stacking and hide offensive controls.")
 panel.tier_buttons[1][2].grab_focus()
 await settle()
 check(game.preview_branch == 1, "Relay future focus must request its coverage preview.")
 game.create_tower(5, Vector3(-4, 0, -3))
 game.selected = game.towers.size() - 1
 panel.refresh()
 check(game.preview_branch == -1, "Selecting another Relay must clear the previous coverage preview.")
 panel.tier_buttons[1][2].grab_focus()
 await settle()
 check("Recipients" in panel.inspection_stats.text and "Amber" in panel.inspection_stats.text, "Coverage preview must show recipient counts and explain colors.")
 panel.inspection_scroll.grab_focus()
 var scroll_event = InputEventKey.new()
 scroll_event.keycode = KEY_END
 scroll_event.pressed = true
 panel.inspection_scroll.gui_input.emit(scroll_event)
 check(panel.inspection_scroll.scroll_vertical > 0, "Preview details must accept keyboard scrolling.")
 if "--fleet-panel-capture" in OS.get_cmdline_user_args():
  DirAccess.make_dir_recursive_absolute("res://work")
  game.selected = 3
  game.credits = 9000
  panel.refresh()
  panel.tier_buttons[2][2].grab_focus()
  await capture("fleet_panel_nova")
  game.selected = game.towers.size() - 1
  panel.refresh()
  panel.tier_buttons[1][2].grab_focus()
  await capture("fleet_panel_relay")
  DisplayServer.window_set_size(Vector2i(960, 600))
  await settle()
  await capture("fleet_panel_relay_960")
 panel.close_button.pressed.emit()
 check(game.selected == -1, "Back to fleet must clear ship selection.")
 game.clear_run()
 await settle()
 if failures == 0: print("FLEET PANEL TEST PASSED: focus/hover parity, future inspection, next-only purchase, owned/excluded/unaffordable states, focus persistence, targeting, all fleet layouts")
 quit(0 if failures == 0 else 1)

func capture(filename: String) -> void:
 game.refresh_ui()
 panel.refresh()
 panel.show()
 await settle()
 game._process(0.0)
 await RenderingServer.frame_post_draw
 assert_card_visible()
 root.get_texture().get_image().save_png("res://work/" + filename + ".png")
 check(panel.position.y + panel.size.y <= root.get_visible_rect().size.y, "Resized inspector must stay within logical viewport.")
 print("FLEET PANEL CAPTURE: res://work/" + filename + ".png")

func assert_card_visible() -> void:
 var focused = root.gui_get_focus_owner()
 check(focused != null and panel.tree_scroll.is_ancestor_of(focused), "Expected a focused tier card inside the upgrade tree.")
 if focused != null and panel.tree_scroll.is_ancestor_of(focused):
  check(panel.tree_scroll.get_global_rect().grow(.5).encloses(focused.get_global_rect()), "The whole focused tier card must be inside the visible scroll viewport.")

func key_event(code: Key, shift = false) -> void:
 var event = InputEventKey.new()
 event.keycode = code
 event.physical_keycode = code
 event.shift_pressed = shift
 event.pressed = true
 root.push_input(event)
 event = event.duplicate()
 event.pressed = false
 root.push_input(event)
 await settle()
