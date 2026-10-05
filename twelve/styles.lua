local P = '__tardis__/graphics/twelve/'
local S = data.raw['gui-style'].default
local C = {
  text = { 0.77, 0.88, 0.9 },
  cream = { 0.9, 0.86, 0.75 },
  cyan = { 0.4, 0.855, 0.875 },
  gold = { 0.867, 0.675, 0.384 },
  muted = { 0.46, 0.64, 0.69 },
  disabled = { 0.29, 0.41, 0.46 },
}
local function empty()
  return { base = { type = 'none' }, shadow = { type = 'none' }, glow = { type = 'none' } }
end
local function skin(name)
  return {
    base = { filename = P .. 'ui-' .. name .. '.png', position = { 0, 0 }, corner_size = 12 },
    shadow = {
      type = 'none',
    },
    glow = {
      type = 'none',
    },
  }
end
local function flat(color)
  -- A white 3x3 patch supplies a flat tint, without inheriting stone, dirt,
  -- bevels or shadows from Factorio's stock progress bars and scroll tracks.
  return {
    base = { filename = P .. 'ui-flat.png', position = { 0, 0 }, corner_size = 1, tint = color },
    shadow = { type = 'none' },
    glow = { type = 'none' },
  }
end
local function button_states(style)
  style.default_graphical_set = skin('button')
  style.hovered_graphical_set = skin('hover')
  style.clicked_graphical_set = skin('active')
  style.disabled_graphical_set = skin('disabled')
  style.selected_graphical_set = skin('active')
  style.selected_hovered_graphical_set = skin('active')
  style.selected_clicked_graphical_set = skin('active')
  style.game_controller_selected_hovered_graphical_set = skin('hover')
  return style
end

data:extend({
  { type = 'font', name = 't12-display-font', from = 'default', size = 25 },
  { type = 'font', name = 't12-body-font', from = 'default', size = 14 },
  { type = 'font', name = 't12-muted-font', from = 'default', size = 12 },
  { type = 'font', name = 't12-subtitle-font', from = 'default-semibold', size = 15 },
  { type = 'font', name = 't12-rail-font', from = 'default', size = 13 },
  {
    type = 'sprite',
    name = 't12-gallifreyan-seal',
    filename = P .. 'ui-gallifreyan-seal.png',
    width = 256,
    height = 256,
    flags = { 'gui-icon' },
  },
  {
    type = 'sprite',
    name = 't12-orbit-divider',
    filename = P .. 'ui-orbit-divider.png',
    width = 768,
    height = 48,
    flags = {
      'gui-icon',
    },
  },
  {
    type = 'sprite',
    name = 't12-route-dial',
    filename = P .. 'ui-route-dial.png',
    width = 512,
    height = 256,
    flags = {
      'gui-icon',
    },
  },
})

S.t12_shell = {
  type = 'frame_style',
  parent = 'frame',
  padding = 12,
  graphical_set = skin('shell'),
  background_graphical_set = empty(),
  horizontal_flow_style = { type = 'horizontal_flow_style', horizontal_spacing = 16 },
  vertical_flow_style = { type = 'vertical_flow_style', vertical_spacing = 8 },
}
S.t12_panel = {
  type = 'frame_style',
  parent = 'inside_shallow_frame',
  padding = 12,
  graphical_set = skin('panel'),
  background_graphical_set = empty(),
  vertical_flow_style = { type = 'vertical_flow_style', vertical_spacing = 8 },
}
S.t12_card = { type = 'frame_style', parent = 't12_panel', padding = 10, graphical_set = skin('card') }
S.t12_amber_card = { type = 'frame_style', parent = 't12_card', graphical_set = skin('amber') }
S.t12_rail = {
  type = 'frame_style',
  parent = 't12_panel',
  padding = 8,
  graphical_set = skin('rail'),
  vertical_flow_style = { type = 'vertical_flow_style', vertical_spacing = 4 },
}
S.t12_title = { type = 'label_style', font = 't12-display-font', font_color = C.cream }
S.t12_text = { type = 'label_style', font = 't12-body-font', font_color = C.text }
S.t12_subtitle = { type = 'label_style', font = 't12-subtitle-font', font_color = C.cyan }
S.t12_muted = { type = 'label_style', font = 't12-muted-font', font_color = C.muted }

S.t12_button = button_states({
  type = 'button_style',
  parent = 'button',
  font = 't12-body-font',
  minimal_width = 0,
  minimal_height = 34,
  padding = 8,
  top_padding = 5,
  bottom_padding = 5,
  clicked_vertical_offset = 0,
  default_font_color = C.text,
  hovered_font_color = { 0.88, 1, 1 },
  clicked_font_color = C.gold,
  disabled_font_color = C.disabled,
  selected_font_color = C.gold,
  selected_hovered_font_color = C.cream,
  selected_clicked_font_color = C.gold,
  draw_shadow_under_picture = false,
  invert_colors_of_picture_when_disabled = false,
  invert_colors_of_picture_when_hovered_or_toggled = false,
})
S.t12_primary =
  { type = 'button_style', parent = 't12_button', default_graphical_set = skin('active'), default_font_color = C.gold }
S.t12_rail_button = {
  type = 'button_style',
  parent = 't12_button',
  font = 't12-rail-font',
  width = 132,
  height = 38,
  minimal_height = 38,
  horizontal_align = 'left',
  left_padding = 9,
  right_padding = 6,
}
S.t12_rail_active = {
  type = 'button_style',
  parent = 't12_rail_button',
  default_graphical_set = skin('active'),
  default_font_color = C.gold,
}
S.t12_slot = button_states({
  type = 'button_style',
  parent = 'slot_button',
  font = 't12-body-font',
  size = 40,
  padding = 0,
  draw_shadow_under_picture = false,
  draw_grayscale_picture = false,
  invert_colors_of_picture_when_disabled = false,
  invert_colors_of_picture_when_hovered_or_toggled = false,
  default_font_color = C.text,
  hovered_font_color = C.cyan,
  clicked_font_color = C.gold,
  selected_font_color = C.gold,
  disabled_font_color = C.disabled,
})
S.t12_sprite_button = { type = 'button_style', parent = 't12_slot', size = 36, minimal_width = 0, minimal_height = 0 }

S.t12_field = {
  type = 'textbox_style',
  parent = 'textbox',
  font = 't12-body-font',
  font_color = C.text,
  disabled_font_color = C.disabled,
  minimal_height = 32,
  padding = 7,
  selection_background_color = { 0.13, 0.35, 0.4 },
  default_background = skin('field'),
  active_background = skin('hover'),
  disabled_background = skin('disabled'),
  game_controller_hovered_background = skin('hover'),
}
S.t12_scrollbar_thumb =
  button_states({ type = 'button_style', parent = 't12_button', minimal_width = 0, minimal_height = 0, padding = 0 })
-- The slender thumb uses flat fills: a 25px nine-slice cannot fit an 8px track.
S.t12_scrollbar_thumb.default_graphical_set = flat({ 0.16, 0.39, 0.45 })
S.t12_scrollbar_thumb.hovered_graphical_set = flat(C.cyan)
S.t12_scrollbar_thumb.clicked_graphical_set = flat(C.gold)
S.t12_vertical_scrollbar = {
  type = 'vertical_scrollbar_style',
  parent = 'vertical_scrollbar',
  width = 8,
  background_graphical_set = flat({ 0.025, 0.07, 0.095 }),
  thumb_button_style = { type = 'button_style', parent = 't12_scrollbar_thumb', width = 8 },
}
S.t12_horizontal_scrollbar = {
  type = 'horizontal_scrollbar_style',
  parent = 'horizontal_scrollbar',
  height = 8,
  background_graphical_set = flat({ 0.025, 0.07, 0.095 }),
  thumb_button_style = { type = 'button_style', parent = 't12_scrollbar_thumb', height = 8 },
}
S.t12_scroll = {
  type = 'scroll_pane_style',
  parent = 'scroll_pane',
  padding = 0,
  margin = 0,
  always_draw_borders = false,
  extra_padding_when_activated = 0,
  extra_margin_when_activated = 0,
  graphical_set = empty(),
  background_graphical_set = empty(),
  vertical_flow_style = { type = 'vertical_flow_style', vertical_spacing = 8 },
  vertical_scrollbar_style = { type = 'vertical_scrollbar_style', parent = 't12_vertical_scrollbar' },
  horizontal_scrollbar_style = { type = 'horizontal_scrollbar_style', parent = 't12_horizontal_scrollbar' },
}
S.t12_dropdown = {
  type = 'dropdown_style',
  parent = 'dropdown',
  minimal_height = 34,
  top_padding = 0,
  bottom_padding = 0,
  left_padding = 0,
  right_padding = 0,
  selector_and_title_spacing = 8,
  button_style = {
    type = 'button_style',
    parent = 't12_button',
    horizontal_align = 'left',
    left_padding = 10,
    right_padding = 6,
  },
  icon = {
    filename = '__core__/graphics/icons/mip/dropdown.png',
    size = 32,
    scale = 0.5,
    mipmap_count = 2,
    flags = { 'gui-icon' },
    tint = C.cyan,
  },
  list_box_style = {
    type = 'list_box_style',
    parent = 'list_box',
    padding = 0,
    maximal_height = 320,
    item_style = {
      type = 'button_style',
      parent = 't12_button',
      horizontal_align = 'left',
      minimal_height = 30,
      left_padding = 10,
      right_padding = 10,
    },
    scroll_pane_style = {
      type = 'scroll_pane_style',
      parent = 't12_scroll',
      padding = 4,
      graphical_set = skin('panel'),
      always_draw_borders = true,
    },
  },
}
S.t12_checkbox = button_states({
  type = 'checkbox_style',
  parent = 'checkbox',
  font = 't12-body-font',
  font_color = C.text,
  disabled_font_color = C.disabled,
  minimal_height = 26,
  text_padding = 8,
  checkmark = { filename = P .. 'ui-check.png', size = 16 },
  disabled_checkmark = { filename = P .. 'ui-check.png', size = 16, tint = { 0.35, 0.45, 0.48 } },
  intermediate_mark = { filename = P .. 'ui-check.png', size = 16, tint = C.gold },
})

S.t12_tab = button_states({
  type = 'tab_style',
  parent = 'tab',
  font = 't12-body-font',
  minimal_height = 36,
  default_font_color = C.text,
  selected_font_color = C.gold,
  disabled_font_color = C.disabled,
  override_graphics_on_edges = false,
})
S.t12_tab_hidden = {
  type = 'tab_style',
  parent = 't12_tab',
  width = 0,
  height = 0,
  minimal_width = 0,
  minimal_height = 0,
  maximal_width = 0,
  maximal_height = 0,
  padding = 0,
  margin = 0,
  increase_height_when_selected = false,
  override_graphics_on_edges = false,
  default_graphical_set = empty(),
  hovered_graphical_set = empty(),
  clicked_graphical_set = empty(),
  disabled_graphical_set = empty(),
  selected_graphical_set = empty(),
  selected_hovered_graphical_set = empty(),
  selected_clicked_graphical_set = empty(),
  game_controller_selected_hovered_graphical_set = empty(),
  left_edge_selected_graphical_set = empty(),
  right_edge_selected_graphical_set = empty(),
  default_badge_graphical_set = empty(),
  selected_badge_graphical_set = empty(),
  disabled_badge_graphical_set = empty(),
  hover_badge_graphical_set = empty(),
  press_badge_graphical_set = empty(),
}
S.t12_tabs = {
  type = 'tabbed_pane_style',
  parent = 'tabbed_pane',
  padding = 0,
  margin = 0,
  vertical_spacing = 0,
  tab_container = {
    type = 'table_style',
    height = 0,
    minimal_height = 0,
    maximal_height = 0,
    padding = 0,
    margin = 0,
    cell_padding = 0,
    horizontal_spacing = 0,
    vertical_spacing = 0,
    background_graphical_set = empty(),
  },
  tab_content_frame = {
    type = 'frame_style',
    parent = 't12_panel',
    padding = 0,
    margin = 0,
    graphical_set = empty(),
    background_graphical_set = empty(),
  },
}
S.t12_progress = {
  type = 'progressbar_style',
  parent = 'progressbar',
  bar_width = 5,
  color = C.cyan,
  bar = flat({ 1, 1, 1 }),
  bar_background = flat({ 0.025, 0.075, 0.105 }),
  font = 't12-muted-font',
  font_color = C.text,
  filled_font_color = C.cream,
  embed_text_in_bar = false,
  side_text_padding = 6,
}
