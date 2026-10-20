## A node for calling components in the newgrounds.io API.
## Should only be used in code.
class_name NewgroundsRequest extends HTTPRequest

const gateway_uri: String = "https://newgrounds.io/gateway_v3.php"

# Errors
const ERR_MISSING_CAPTCHA = 1
const ERR_CANCELLED = 998
const ERR_FAILED_REQUEST = 999

const ERR_SESSION_ID_MISSING = 102
const ERR_INVALID_SCOREBOARD_ID = 203
const ERR_INVALID_SESSION = 104
const ERR_USER_NOT_LOGGED_IN = 110
const ERR_SESSION_CANCELLED = 111

const ERR_MEDAL_NOT_FOUND = 202

signal on_success(data)
signal on_error(error)

signal on_response(response: NewgroundsResponse)

signal on_cancel()

var app_id: String
var aes_key: String
var session: NewgroundsSession

var aes: AESContext

var _result_field := ""
var _custom_call := false
var _completed := false

func init(app_id: String, aes_key: String, session: NewgroundsSession = NewgroundsSession.new(), aes_context = AESContext.new()):
	self.app_id = app_id
	self.aes_key = aes_key
	self.session = session
	self.aes = aes_context
	timeout = 10.0

func create(component, parameters, result_field = "", encrypt = true) -> HTTPRequest:
	_result_field = result_field
	request_completed.connect(_request_completed)

	if app_id.is_empty():
		_finish_with_error.call_deferred(ERR_FAILED_REQUEST, "Newgrounds App ID is missing.")
		return self

	if encrypt:
		var key_bits = Marshalls.base64_to_raw(aes_key).size() << 3
		if key_bits != 128 and key_bits != 256:
			_finish_with_error.call_deferred(ERR_FAILED_REQUEST, "Newgrounds AES key is missing or invalid.")
			return self

	var call_parameters = {
		"component": component,
	}
	if parameters:
		call_parameters.parameters = parameters

	var call = null
	if encrypt:
		var iv = generate_iv()

		var content = JSON.stringify(call_parameters).to_utf8_buffer()

		var content_size = content.size()
		var padding = 16 - content_size % 16
		if padding > 0:
			var new_size = content_size + padding
			content.resize(new_size)
			for i in range(padding):
				content.set(new_size - i - 1, padding)

		var aes_key_bytes = Marshalls.base64_to_raw(aes_key)
		aes.start(AESContext.MODE_CBC_ENCRYPT, aes_key_bytes, iv)
		var encrypted = aes.update(content)
		aes.finish()

		var res = iv
		res.append_array(encrypted)

		call = {
			"secure": Marshalls.raw_to_base64(res),
		}
	else:
		call = call_parameters

	var input_parameters = {
		"app_id": app_id,
		"call": call,
		# "debug": true,
	}

	if session.id:
		input_parameters.session_id = session.id

	var request_error = request(
		gateway_uri,
		["Content-Type: application/x-www-form-urlencoded"],
		HTTPClient.METHOD_POST,
		"input=" + JSON.stringify(input_parameters).uri_encode()
	)

	if request_error != OK:
		_finish_with_error.call_deferred(ERR_FAILED_REQUEST, "Could not start the request: %s" % error_string(request_error))

	return self

func cancel() -> void:
	if _completed:
		return
	_completed = true
	cancel_request()
	var response := NewgroundsResponse.new()
	response.error = ERR_CANCELLED
	response.error_message = "Request cancelled."
	on_response.emit(response)
	on_cancel.emit()
	queue_free()

func custom_request(url: String) -> void:
	request_completed.connect(_request_completed)
	_custom_call = true

	var request_error = request(url)
	if request_error != OK:
		_finish_with_error.call_deferred(ERR_FAILED_REQUEST, "Could not start the request: %s" % error_string(request_error))

func _request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if _completed:
		return
	_completed = true
	queue_free()

	var response := NewgroundsResponse.new()

	if result != RESULT_SUCCESS:
		_fail(response, ERR_FAILED_REQUEST, "Could not fulfill request.")
		return

	var body_string = body.get_string_from_utf8()

	if _custom_call:
		if response_code >= 200 and response_code < 300:
			response.data = body_string
			on_success.emit(body_string)
			on_response.emit(response)
		else:
			_fail(response, ERR_FAILED_REQUEST, body_string)
		return

	if response_code < 200 or response_code > 299:
		var message := "Request error code %s" % response_code
		if response_code == 405:
			message += ". Newgrounds might be under maintenance."
		_fail(response, ERR_FAILED_REQUEST, message)
		return

	var res = JSON.parse_string(body_string)
	if not (res is Dictionary):
		_fail(response, ERR_FAILED_REQUEST, "Could not parse the Newgrounds response.")
		return

	if not res.get("success", false):
		var error_code := ERR_FAILED_REQUEST
		var error_message := "Unknown Newgrounds error."
		var api_error = res.get("error")
		if api_error is Dictionary:
			error_code = int(api_error.get("code", error_code))
			error_message = str(api_error.get("message", error_message))
		elif api_error != null:
			error_message = str(api_error)
		_fail(response, error_code, error_message)
		return

	var result_wrapper = res.get("result")
	if not (result_wrapper is Dictionary):
		_fail(response, ERR_FAILED_REQUEST, "Unexpected Newgrounds response.")
		return

	var result_data = result_wrapper.get("data")
	if not (result_data is Dictionary):
		_fail(response, ERR_FAILED_REQUEST, "Unexpected Newgrounds response.")
		return

	if not result_data.get("success", false):
		var api_error = result_data.get("error", {})
		var error_code := int(api_error.get("code", ERR_FAILED_REQUEST))
		var error_message := str(api_error.get("message", "Unknown Newgrounds error."))
		_fail(response, error_code, error_message)
		return

	if _result_field:
		response.data = result_data.get(_result_field)
		on_success.emit(response.data)
	else:
		response.data = result_data
		on_success.emit(response.data)

	on_response.emit(response)

func _fail(response: NewgroundsResponse, code: int, message: String) -> void:
	response.error = code
	response.error_message = message
	on_response.emit(response)
	on_error.emit(message)

func _finish_with_error(code: int, message: String) -> void:
	if _completed:
		return
	_completed = true
	var response := NewgroundsResponse.new()
	_fail(response, code, message)
	queue_free()

func generate_iv() -> PackedByteArray:
	var arr = PackedByteArray()
	arr.resize(16)
	for i in range(16):
		arr.set(i, randi() % 256)
	return arr
