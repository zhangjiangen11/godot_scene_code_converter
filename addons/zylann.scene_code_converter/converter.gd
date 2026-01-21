@tool

# Converts a scene branch into C++ engine-side code that will build it.

var _vars = []
var _lines : Array[String] = []


func convert_branch(root: Node) -> String:
	_vars.clear()
	_lines.clear()
	_process_node(root, root, 0,"")

	var str : String
	for s in _lines:
		if s.length() > 0:
			str += s + "\n"
	return str


func _process_node(node: Node, root: Node, space: int, parent_var_name : String) -> Dictionary:
	var klass_name := node.get_class()
	var space_str = "\t"
	for i in space:
		space_str += "\t"
	var var_name = ""
	if node != root:
		if node.name.is_valid_ascii_identifier():
			var_name = node.name
		else:
			var_name = _pascal_to_snake(klass_name)
		if var_name in _vars:
			var incremented_name = var_name
			var i = 1
			while incremented_name in _vars:
				i += 1
				incremented_name = str(var_name, i)
			var_name = incremented_name
		_vars.append(var_name)
	
	# Create the node in a variable if necessary
	if var_name != "":
		if not _has_default_node_name(node):
			_lines.append( space_str + str("// 创建节点:", node.name))
		_lines.append(space_str + str(klass_name, " *", var_name, " = memnew(", klass_name, ");"))
		_lines.append(space_str + str(var_name, "->set_name(\"", var_name, "\" );"))
	
		if parent_var_name == "":
			_lines.append( space_str + str("add_child(", var_name, ");"))
		else:
			_lines.append( space_str + str(parent_var_name, "->add_child(", var_name, ");"))
	# Ignore properties which are sometimes overriden by other factors
	var ignored_properties := []
	if node is Control:
		if (node.get_parent() is Container) or node == root:
			ignored_properties += [
				"margin_left",
				"margin_right",
				"margin_top",
				"margin_bottom",
				"anchor_left",
				"anchor_right",
				"anchor_top",
				"anchor_bottom"
			]
		if node.get_parent() is TabContainer:
			ignored_properties.append("visible")

	var default_instance: Node = ClassDB.instantiate(klass_name)
	assert(default_instance is Node)

	# Set properties
	var props = node.get_property_list()
	
	for prop in props:
		if (prop.usage & PROPERTY_USAGE_STORAGE) == 0:
			continue
		if prop.name in ignored_properties:
			continue
		var default_value = default_instance.get(prop.name)
		var current_value = node.get(prop.name)
		if current_value != default_value:
			#print(prop.name, " = ", current_value)
			var set_code := _get_property_set_code(node, prop.name, current_value)
			if set_code.length() < 3:
				_lines.append("")
			else:	
				if var_name == "":
					_lines.append(space_str + str(set_code, ";"))
				else:
					_lines.append(space_str + str(var_name, "->", set_code, ";"))

	default_instance.free()

	# Process children
	if node.get_child_count() > 0:
		_lines.append(space_str + "{")
		
		for i in node.get_child_count():
			var child = node.get_child(i)
			if child.owner == null:
				continue
			var child_info = _process_node(child, root, space + 1,var_name)
			_lines.append("")
	
		_lines.append(space_str + "}")
	return {
		"var_name": var_name
	}

static func get_grow_sirection_int_codes(index : int):
		match  index:
			0:
				return "Control::GROW_DIRECTION_BEGIN"
			1:
				return "Control::GROW_DIRECTION_END"
			2:
				return "Control::GROW_DIRECTION_BOTH"
		return ""

static func _get_property_set_code(obj: Object, property_name: String, value) -> String:
	var value_code := _value_to_code(value)
	
	# We first check very specific cases for best translation (but requires specific code)
	if property_name.find("/") >0:
		# 处理主体参数的设置
		return str("set(\"",property_name,"\",", value_code,")")
	if obj is Control:
		match property_name:
			"margin_left":
				return str("set_margin(MARGIN_LEFT, ", value_code, " * EDSCALE)")
			"margin_right":
				return str("set_margin(MARGIN_RIGHT, ", value_code, " * EDSCALE)")
			"margin_top":
				return str("set_margin(MARGIN_TOP, ", value_code, " * EDSCALE)")
			"margin_bottom":
				return str("set_margin(MARGIN_BOTTOM, ", value_code, " * EDSCALE)")

			"anchor_left":
				return str("set_anchor(SIDE_EFT, ", value_code, ")")
			"anchor_right":
				return str("set_anchor(SIDE_RIGHT, ", value_code, ")")
			"anchor_top":
				return str("set_anchor(SIDE_TOP, ", value_code, ")")
			"anchor_bottom":
				return str("set_anchor(SIDE_BOTTOM, ", value_code, ")")
			"grow_horizontal":
				return str("set_h_grow_direction(", get_grow_sirection_int_codes(value), ")")
			"grow_vertical":
				return str("set_v_grow_direction(", get_grow_sirection_int_codes(value), ")")
				
			"size_flags_vertical":
				return str("set_v_size_flags(", _get_size_flags_code(value), ")")
			"size_flags_horizontal":
				return str("set_h_size_flags(", _get_size_flags_code(value), ")")
			"layout_mode":
				return str("set_layout_mode(", _layout_mode[value], ")")
			"self_modulate":
				return str("set_self_modulate(", value_code, ")")
			"modulate":
				return str("set_modulate(", value_code, ")")
			"offset_left":
				if(obj.get("layout_mode") != 1):
					return ""
				return str("set_offset(SIDE_LEFT,", value ," )")
				
			"offset_top":
				if(obj.get("layout_mode") != 1):
					return ""
				return str("set_offset(SIDE_TOP,", value ," )")
			"offset_right":
				if(obj.get("layout_mode") != 1):
					return ""
				return str("set_offset(SIDE_RIGHT,", value ," )")
			"offset_bottom":
				if(obj.get("layout_mode") != 1):
					return ""
				return str("set_offset(SIDE_BOTTOM,", value ," )")
			"anchors_preset":
				if value < 0:
					return str("_set_anchors_layout_preset(", -1 ," )")
				return str("set_anchors_and_offsets_preset(", _layout_preset_codes[value] ," )")
	
	if obj is TextureRect:
		match property_name:
			"stretch_mode":
				return str("set_stretch_mode(", _texture_rect_stretch_mode_codes[value], ")")
			"expand_mode":
				return str("set_expand_mode(", _texture_rect_expand_mode[value], ")")
	
	if obj is BoxContainer:
		match property_name:
			"alignment":
				return str("set_alignment(", _box_container_alignment_codes[value], ")")
	
	if obj is Label:
		match property_name:
			"horizontal_alignment":
				return str("set_horizontal_alignment(", _label_hor_align_codes[value], ")")
			"vertical_alignment":
				return str("set_vertical_alignment(", _label_ver_align_codes[value], ")")
	
	
	# Assume regular setter
	return str("set_", property_name, "(", value_code, ")")

	# This should work but ideally we should avoid it because it's slow
	#return str("set(\"", property_name, "\", ", value_code, ")")


static func _value_to_code(v) -> String:
	match (typeof(v)):
		TYPE_BOOL:
			if v:
				return "true"
			else:
				return "false"
		TYPE_VECTOR2:
			return str("Vector2(", v.x, ", ", v.y, ")")
		TYPE_VECTOR3:
			return str("Vector3(", v.x, ", ", v.y, ", ", v.z, ")")
		TYPE_VECTOR2I:
			return str("Vector2i(", v.x, ", ", v.y, ")")
		TYPE_VECTOR3I:
			return str("Vector3i(", v.x, ", ", v.y, ", ", v.z, ")")
		TYPE_COLOR:
			return str("Color(", v.r, ", ", v.g, ", ", v.b, ", ", v.a, ")")
		TYPE_STRING:
			return str("L\"", v.c_escape(), "\"")
		TYPE_STRING_NAME:
			return str("SNAME(L\"", v.c_escape(), "\")")
		TYPE_OBJECT:
			if v is Resource:
				return v.resource_path
			else:
				return "nullptr /* TODO reference here */"
		_:
			return str(v)


static func _pascal_to_snake(src: String) -> String:
	var dst = ""
	for i in len(src):
		var c: String = src[i]
		dst += c.to_lower()
		if i + 1 < len(src):
			var next_c = src[i + 1]
			if next_c != next_c.to_lower():
				dst += "_"
	return dst


static func _has_default_node_name(node: Node) -> bool:
	var cname = node.get_class()
	if node.name == cname:
		return true
	# Let's go the dumb way
	for i in range(2, 10):
		if node.name == str(cname, i):
			return true
	return false


# Some setters have a different name in engine code
static var _aliased_setters : Dictionary = {
	Control: {
		"rect_min_size": "set_custom_minimum_size"
	},
	AcceptDialog: {
		"window_title": "set_title"
	}
}

static func _get_size_flags_code(sf: int) -> String:
	match sf:
		Control.SIZE_EXPAND:
			return "Control::SIZE_EXPAND"
		Control.SIZE_EXPAND_FILL:
			return "Control::SIZE_EXPAND_FILL"
		Control.SIZE_FILL:
			return "Control::SIZE_FILL"
		Control.SIZE_SHRINK_CENTER:
			return "Control::SIZE_SHRINK_CENTER"
		Control.SIZE_SHRINK_END:
			return "Control::SIZE_SHRINK_END"
		_:
			return str(sf)

# IF ONLY GODOT ALLOWED US TO GET ENUM NAMES AS STRINGS

const _label_hor_align_codes = {
	HORIZONTAL_ALIGNMENT_LEFT: "HorizontalAlignment::HORIZONTAL_ALIGNMENT_LEFT",
	HORIZONTAL_ALIGNMENT_CENTER: "HorizontalAlignment::HORIZONTAL_ALIGNMENT_CENTER",
	HORIZONTAL_ALIGNMENT_RIGHT: "HorizontalAlignment::HORIZONTAL_ALIGNMENT_RIGHT",
	HORIZONTAL_ALIGNMENT_FILL: "HorizontalAlignment::HORIZONTAL_ALIGNMENT_FILL"
}

const _label_ver_align_codes = {
	VERTICAL_ALIGNMENT_TOP: "VerticalAlignment::VERTICAL_ALIGNMENT_TOP",
	VERTICAL_ALIGNMENT_CENTER: "VerticalAlignment::VERTICAL_ALIGNMENT_CENTER",
	VERTICAL_ALIGNMENT_BOTTOM: "VerticalAlignment::VERTICAL_ALIGNMENT_BOTTOM",
	VERTICAL_ALIGNMENT_FILL: "VerticalAlignment::VERTICAL_ALIGNMENT_FILL"
}
const _layout_mode = {
	0: "Control::LAYOUT_MODE_POSITION",
	1: "Control::LAYOUT_MODE_ANCHORS",
	2: "Control::LAYOUT_MODE_CONTAINER",
	3: "Control::LAYOUT_MODE_UNCONTROLLED"
}
const _texture_rect_expand_mode = {
	TextureRect.EXPAND_KEEP_SIZE: "TextureRect.EXPAND_KEEP_SIZE",
	TextureRect.EXPAND_IGNORE_SIZE: "TextureRect.EXPAND_IGNORE_SIZE",
	TextureRect.EXPAND_FIT_WIDTH: "TextureRect.EXPAND_FIT_WIDTH",
	TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL: "TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL",
	TextureRect.EXPAND_FIT_HEIGHT: "TextureRect.EXPAND_FIT_HEIGHT",
	TextureRect.EXPAND_FIT_HEIGHT_PROPORTIONAL: "TextureRect.EXPAND_FIT_HEIGHT_PROPORTIONAL",
}

const _box_container_alignment_codes = {
	BoxContainer.ALIGNMENT_BEGIN: "BoxContainer::ALIGNMENT_BEGIN",
	BoxContainer.ALIGNMENT_CENTER: "BoxContainer::ALIGNMENT_CENTER",
	BoxContainer.ALIGNMENT_END: "BoxContainer::ALIGNMENT_END",
}

const _grow_sirection_codes = {
	Control.GROW_DIRECTION_BEGIN: "Control::GROW_DIRECTION_BEGIN",
	Control.GROW_DIRECTION_END: "Control::GROW_DIRECTION_END",
	Control.GROW_DIRECTION_BOTH: "Control::GROW_DIRECTION_BOTH",
}

const _grow_sirection_int_codes = {
	0: "Control::GROW_DIRECTION_BEGIN",
	1: "Control::GROW_DIRECTION_END",
	2: "Control::GROW_DIRECTION_BOTH",
}

const _layout_preset_codes = {
	Control.PRESET_TOP_LEFT: "Control::PRESET_TOP_LEFT",
	Control.PRESET_TOP_RIGHT: "Control::PRESET_TOP_RIGHT",
	Control.PRESET_BOTTOM_LEFT: "Control::PRESET_BOTTOM_LEFT",
	Control.PRESET_BOTTOM_RIGHT: "Control::PRESET_BOTTOM_RIGHT",
	Control.PRESET_CENTER_LEFT: "Control::PRESET_CENTER_LEFT",
	Control.PRESET_CENTER_TOP: "Control::PRESET_CENTER_TOP",
	Control.PRESET_CENTER_RIGHT: "Control::PRESET_CENTER_RIGHT",
	Control.PRESET_CENTER_BOTTOM: "Control::PRESET_CENTER_BOTTOM",
	Control.PRESET_CENTER: "Control::PRESET_CENTER",
	Control.PRESET_LEFT_WIDE: "Control::PRESET_LEFT_WIDE",
	Control.PRESET_TOP_WIDE: "Control::PRESET_TOP_WIDE",
	Control.PRESET_RIGHT_WIDE: "Control::PRESET_RIGHT_WIDE",
	Control.PRESET_BOTTOM_WIDE: "Control::PRESET_BOTTOM_WIDE",
	Control.PRESET_VCENTER_WIDE: "Control::PRESET_VCENTER_WIDE",
	Control.PRESET_HCENTER_WIDE: "Control::PRESET_HCENTER_WIDE",
	Control.PRESET_FULL_RECT: "Control::PRESET_FULL_RECT",
}

const _texture_rect_stretch_mode_codes = {
	TextureRect.STRETCH_SCALE: "TextureRect::STRETCH_SCALE",
	TextureRect.STRETCH_TILE: "TextureRect::STRETCH_TILE",
	TextureRect.STRETCH_KEEP: "TextureRect::STRETCH_KEEP",
	TextureRect.STRETCH_KEEP_CENTERED: "TextureRect::STRETCH_KEEP_CENTERED",
	TextureRect.STRETCH_KEEP_ASPECT: "TextureRect::STRETCH_KEEP_ASPECT",
	TextureRect.STRETCH_KEEP_ASPECT_CENTERED: "TextureRect::STRETCH_KEEP_ASPECT_CENTERED",
	TextureRect.STRETCH_KEEP_ASPECT_COVERED: "TextureRect::STRETCH_KEEP_ASPECT_COVERED"
}
