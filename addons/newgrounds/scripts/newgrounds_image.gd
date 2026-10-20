extends TextureRect

@export var placeholder: Texture2D = null

@export var url: String: set = _set_url

static var cached_images := Dictionary()

const MAX_CACHED_IMAGES := 64
const REQUEST_TIMEOUT := 10.0

signal on_image_start_loading()
signal on_image_loaded(image: ImageTexture)
signal on_image_failed()

var request: HTTPRequest

func _ready():
	if texture == null:
		texture = placeholder

func _set_url(u):
	if u == url:
		return

	url = u
	_cancel_request()

	if url.is_empty():
		texture = placeholder
		return

	on_image_start_loading.emit()

	if not Engine.is_editor_hint() and cached_images.has(url):
		var cached: ImageTexture = cached_images[url]
		texture = cached
		on_image_loaded.emit(cached)
		return

	request = HTTPRequest.new()
	request.timeout = REQUEST_TIMEOUT
	add_child(request)
	request.request_completed.connect(_http_request_completed.bind(request))

	var error = request.request(url)
	if error != OK:
		push_error("Newgrounds: could not request image %s (%s)." % [url, error_string(error)])
		_cancel_request()
		on_image_failed.emit()

func _cancel_request() -> void:
	if is_instance_valid(request):
		request.cancel_request()
		request.queue_free()
	request = null

func _http_request_completed(result, response_code, headers: PackedStringArray, body, completed_request: HTTPRequest):
	if is_instance_valid(completed_request):
		completed_request.queue_free()

	if completed_request != request:
		return
	request = null

	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code > 299:
		push_error("Newgrounds: image couldn't be downloaded: %s" % url)
		on_image_failed.emit()
		return

	var content_type = "png"
	for header in headers:
		var lower := header.to_lower()
		if lower.begins_with("content-type"):
			var pieces := lower.split(":", false, 1)
			if pieces.size() > 1:
				var mime := pieces[1].split(";")[0].strip_edges().split("/")
				if mime.size() > 1:
					content_type = mime[1].strip_edges()
			break

	var image = Image.new()
	var error = ERR_FILE_UNRECOGNIZED
	match content_type:
		"png":
			error = image.load_png_from_buffer(body)
		"webp":
			error = image.load_webp_from_buffer(body)
		"jpg", "jpeg":
			error = image.load_jpg_from_buffer(body)
		"svg":
			error = image.load_svg_from_buffer(body)

	if error != OK:
		push_error("Newgrounds: couldn't decode image %s (%s)." % [url, error_string(error)])
		on_image_failed.emit()
		return

	var image_texture := ImageTexture.create_from_image(image)
	texture = image_texture
	if not Engine.is_editor_hint():
		if cached_images.size() >= MAX_CACHED_IMAGES:
			cached_images.clear()
		cached_images[url] = image_texture
	on_image_loaded.emit(image_texture)
