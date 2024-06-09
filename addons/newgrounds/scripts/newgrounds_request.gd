## A node for calling components in the newgrounds.io API.
## Should only be used in code.
class_name NewgroundsRequest extends HTTPRequest

const gateway_uri:String = "https://newgrounds.io/gateway_v3.php"

# Errors
const ERR_MISSING_CAPTCHA = 1;
const ERR_FAILED_REQUEST = 999;

const ERR_SESSION_ID_MISSING = 102;
const ERR_INVALID_SCOREBOARD_ID = 203;
const ERR_INVALID_SESSION = 104;
const ERR_USER_NOT_LOGGED_IN = 110;
const ERR_SESSION_CANCELLED = 111;

const ERR_MEDAL_NOT_FOUND = 202;

signal on_success(data);
signal on_error(error);

signal on_response(response: NewgroundsResponse);

signal on_cancel();

var pending: bool = false;

var app_id: String;
var aes_key: String;
var session: NewgroundsSession;

var aes: AESContext;

var _result_field = ""

func init(app_id: String, aes_key: String, session:NewgroundsSession = NewgroundsSession.new(), aes_context = AESContext.new()):
	self.app_id = app_id;
	
	self.aes_key = aes_key;
	
	self.session = session;
	self.aes = aes_context;
	self.timeout = 10.0
	
func create(component, parameters, result_field = "", encrypt = true) -> HTTPRequest:
	_result_field = result_field
	request_completed.connect(_request_completed)
	
	var call_parameters = {
		"component": component,
	}
	if parameters:
		call_parameters.parameters = parameters;

	var call = null
	if encrypt:
		var iv = generate_iv()
		
		var contentString = JSON.stringify(call_parameters)
		var content = contentString.to_utf8_buffer()
		
		var contentSize = content.size()
		var padding = 16 - contentSize % 16
		if padding > 0:
			var newSize = contentSize + padding
			content.resize(newSize);
			var pbyte = padding;
			for i in range(padding):
				content.set(newSize - i - 1, pbyte)
		
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
	
	if (session.id):
		input_parameters.session_id = session.id
	
	var reqErr = request(
		gateway_uri,
		["Content-Type: application/x-www-form-urlencoded"],
		HTTPClient.METHOD_POST,
		"input=" + JSON.stringify(input_parameters).uri_encode()
	)
	
	pending = true;
	
	return self
	
func cancel():
	pending = false;
	cancel_request()
	on_cancel.emit();
	queue_free();

var _custom_call = false;
func custom_request(url: String):
	request_completed.connect(_request_completed)
	
	pending = true
	_custom_call = true;
	request(url)

func _request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	queue_free()

	pending = false;
	var resp = NewgroundsResponse.new()
	
	if result != RESULT_SUCCESS:
		resp.error = ERR_FAILED_REQUEST
		resp.error_message = "Could not fulfill request."
		resp.data = null;
		on_response.emit(resp);
		on_error.emit(resp.error_message);
		return
	
	var body_string = body.get_string_from_utf8()
	
	if _custom_call:
		if response_code >= 200 and response_code < 300:
			resp.data = body_string
			on_success.emit(body_string)
			on_response.emit(resp)
		else:
			resp.error = FAILED
			resp.error_message = body_string
			on_response.emit(resp)
			on_error.emit(body_string);
		return
		

	var res = JSON.parse_string(body_string)
	if res == null and response_code < 200 or response_code > 299:
		resp.error = ERR_FAILED_REQUEST
		resp.error_message = "Request error code %s" % response_code
		if response_code == 405:
			resp.error_message += ". Newgrounds might be under maintenance."
		resp.data = null;
		on_response.emit(resp);
		on_error.emit(resp.error_message)
		return
		
	if !res.success:
		on_error.emit(res.error)
		resp.error = FAILED
		resp.error_message = res.error
		on_response.emit(resp)
		return
	
	var d = res.result.data;
	if !d.success:
		on_error.emit(d.error)
		resp.error = d.error.code if d.error.code != 0 else ERR_FAILED_REQUEST
		resp.error_message = d.error.message
		on_response.emit(resp)
		return
	
	if _result_field:
		on_success.emit(d[_result_field])
		resp.data = d[_result_field]
	else:
		on_success.emit(d);
		resp.data = d
	
	on_response.emit(resp);
	pass

func generate_iv() -> PackedByteArray:
	var arr = PackedByteArray()
	arr.resize(16)
	for i in range(16):
		arr.set(i, randi() % 0xff)
	return arr
