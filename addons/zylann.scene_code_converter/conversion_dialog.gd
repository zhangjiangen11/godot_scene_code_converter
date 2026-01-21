@tool
extends AcceptDialog

const Util = preload("./util.gd")

@onready var _text_edit : TextEdit  = $VBoxContainer/TextEdit


func _ready():
	if Util.is_in_edited_scene(self):
		return


func set_code(code: String):
	_text_edit.set("theme_override_font_sizes/font_size",10)
	_text_edit.text = code


func _on_CopyToClipboard_pressed():
	DisplayServer.clipboard_set(_text_edit.text)


func _on_Ok_pressed():
	hide()
