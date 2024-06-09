extends TextureRect

@export var placeholder: Texture2D = null

@export var url: String: set = _set_url;

static var cached_images := Dictionary()

signal on_image_start_loading();
signal on_image_loaded(image:Image);


func _ready():
	texture = placeholder;

var request: HTTPRequest;
func _set_url(u):
	if u == url:
		return
	
	url = u;
	if !url:
		texture = placeholder;
		return
	
	on_image_start_loading.emit();
	
	if request && is_instance_valid(request):
		request.cancel_request()
		request.queue_free()
	
	if !Engine.is_editor_hint() and cached_images.has(url):
		texture = cached_images[url]
		on_image_loaded.emit(texture.get_image());
		return;
	
	request = HTTPRequest.new()
	add_child(request)
	request.request_completed.connect(_http_request_completed)
	# Perform the HTTP request. The URL below returns a PNG image as of writing.
	var error = request.request(url)
	if error != OK:
		push_error("An error occurred in the HTTP request.")
		request.queue_free()
	
func _http_request_completed(result, response_code, headers:PackedStringArray, body):
	if result != HTTPRequest.RESULT_SUCCESS:
		push_error("Image couldn't be downloaded. Try a different image.")
	var content_type = 'png'
	for h in headers:
		if h.begins_with('content-type'):
			content_type = h.split(':')[1].split("/")[1]
			break;
	var s = size;
	var image = Image.new()
	var error;
	match (content_type):
		'png':
			error = image.load_png_from_buffer(body)
		'webp':
			error = image.load_webp_from_buffer(body)
		'jpg', 'jpeg':
			error = image.load_jpg_from_buffer(body)
		'svg':
			error = image.load_svg_from_buffer(body)
	
	if error != OK:
		push_error("Couldn't load the image.")
	
	
	texture = ImageTexture.create_from_image(image)
	if !Engine.is_editor_hint():
		cached_images[url] = texture;
	on_image_loaded.emit(texture);
	request.queue_free()
