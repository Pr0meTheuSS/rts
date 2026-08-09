class_name BaseParticleMonitor
extends PanelContainer

## Общие параметры графика (домены и пр.) задаются в наследниках
var use_particles := true
var poll_interval := 0.0

var title := ""
var horizontal_lines := {}
var vertical_lines := {}

var series: Array[GraphSeries] = []

var _title_label: Label
var _plot_area: Control
var _margin_container: MarginContainer

func _build_ui_common() -> void:
	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.size_flags_horizontal = SIZE_EXPAND | SIZE_FILL
	vbox.size_flags_vertical   = SIZE_EXPAND | SIZE_FILL
	add_child(vbox)

	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.size_flags_horizontal = SIZE_EXPAND | SIZE_FILL
	_title_label.text = title
	vbox.add_child(_title_label)

	_margin_container = MarginContainer.new()
	_margin_container.name = "MarginContainer"
	_margin_container.size_flags_horizontal = SIZE_EXPAND | SIZE_FILL
	_margin_container.size_flags_vertical   = SIZE_EXPAND | SIZE_FILL
	vbox.add_child(_margin_container)

	# _plot_area добавляется в наследниках
