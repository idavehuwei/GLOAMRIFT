extends PanelContainer
## 网页 .panel 四角黄铜折角。


func _ready() -> void:
	resized.connect(queue_redraw)
	item_rect_changed.connect(queue_redraw)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_VISIBILITY_CHANGED:
		queue_redraw()


func _draw() -> void:
	var c := Color(0.831, 0.71, 0.416, 0.92)
	var m := 10.0
	var L := 16.0
	var s := size
	# 左上
	draw_line(Vector2(m, m), Vector2(m + L, m), c, 1.2)
	draw_line(Vector2(m, m), Vector2(m, m + L), c, 1.2)
	# 右上
	draw_line(Vector2(s.x - m, m), Vector2(s.x - m - L, m), c, 1.2)
	draw_line(Vector2(s.x - m, m), Vector2(s.x - m, m + L), c, 1.2)
	# 左下
	draw_line(Vector2(m, s.y - m), Vector2(m + L, s.y - m), c, 1.2)
	draw_line(Vector2(m, s.y - m), Vector2(m, s.y - m - L), c, 1.2)
	# 右下
	draw_line(Vector2(s.x - m, s.y - m), Vector2(s.x - m - L, s.y - m), c, 1.2)
	draw_line(Vector2(s.x - m, s.y - m), Vector2(s.x - m, s.y - m - L), c, 1.2)
	var inner := Rect2(Vector2(4, 4), s - Vector2(8, 8))
	draw_rect(inner, Color(0.69, 0.55, 0.31, 0.14), false, 1.0)
