extends HTTPRequest
## A node for calling components in the newgrounds.io API.
## Should only be used in code.
class_name NewgroundsRequest

const gateway_uri:String = "https://newgrounds.io/gateway_v3.php"

signal on_success(data);
signal on_error(error);

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
	
func create(component, parameters, result_field = "", encrypt = true) -> HTTPRequest:
	_result_field = result_field
	request_completed.connect(_request_completed)
	
	var call_parameters = {
		"component": component,
	}
	if parameters:
		call_parameters.parameters = parameters;
	
	#print(component)
	#print(parameters)
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
		# "debug": true,
		"call": call,
	}
	
	if (session.id):
		input_parameters.session_id = session.id

	request(
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

func _request_completed(result, response_code, headers, body):
	queue_free()
	pending = false;
	
	var body_string = body.get_string_from_utf8()
	
	if _custom_call:
		if response_code == 200:
			on_success.emit(body_string)
		else:
			on_error.emit(body_string);
		return
	
	var res = JSON.parse_string(body_string)
	if !res.success:
		on_error.emit(res.error)
		return
	var d = res.result.data;
	if !d.success:
		on_error.emit(d.error)
		return
	
	if _result_field:
		on_success.emit(d[_result_field])
	else:
		on_success.emit(d);
	pass

func generate_iv() -> PackedByteArray:
	var arr = PackedByteArray()
	arr.resize(16)
	for i in range(16):
		arr.set(i, randi() % 0xff)
	return arr
