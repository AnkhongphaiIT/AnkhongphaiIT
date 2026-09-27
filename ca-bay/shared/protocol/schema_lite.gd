class_name SchemaLite
extends RefCounted
## Bộ kiểm JSON Schema tối giản cho các payload trong data/contracts/network_contract.json.
## Hỗ trợ đúng tập từ khóa hợp đồng dùng: type (kể cả mảng type), const, enum, anyOf,
## properties/required/additionalProperties, items/minItems/maxItems/uniqueItems,
## minLength/maxLength/pattern/format(uuid), minimum/maximum.
## Từ khóa lạ -> lỗi (fail closed) để không vô tình chấp nhận dữ liệu chưa kiểm.

const _KNOWN := {
	"type": true, "const": true, "enum": true, "anyOf": true, "properties": true,
	"required": true, "additionalProperties": true, "items": true, "minItems": true,
	"maxItems": true, "uniqueItems": true, "minLength": true, "maxLength": true,
	"pattern": true, "format": true, "minimum": true, "maximum": true,
	"description": true, "title": true, "$comment": true,
}

static var _regex_cache: Dictionary = {}
static var _uuid_re: RegEx


## Trả về "" nếu hợp lệ, hoặc mô tả lỗi đầu tiên.
static func validate(value: Variant, schema: Dictionary, path: String = "$") -> String:
	for k in schema:
		if not _KNOWN.has(k):
			return "%s: từ khóa schema chưa hỗ trợ '%s'" % [path, k]
	if schema.has("anyOf"):
		var ok := false
		for sub in schema["anyOf"]:
			if validate(value, sub, path) == "":
				ok = true
				break
		if not ok:
			return "%s: không khớp anyOf" % path
	if schema.has("const") and not _equal(value, schema["const"]):
		return "%s: phải bằng %s" % [path, str(schema["const"])]
	if schema.has("enum"):
		var found := false
		for e in schema["enum"]:
			if _equal(value, e):
				found = true
				break
		if not found:
			return "%s: giá trị không nằm trong enum" % path
	if schema.has("type"):
		var types: Array = schema["type"] if schema["type"] is Array else [schema["type"]]
		var matched := false
		for t in types:
			if _is_type(value, String(t)):
				matched = true
				break
		if not matched:
			return "%s: sai kiểu (cần %s)" % [path, str(types)]
	match typeof(value):
		TYPE_DICTIONARY:
			return _validate_object(value, schema, path)
		TYPE_ARRAY:
			return _validate_array(value, schema, path)
		TYPE_STRING:
			return _validate_string(value, schema, path)
		TYPE_INT, TYPE_FLOAT:
			return _validate_number(value, schema, path)
	return ""


static func _validate_object(obj: Dictionary, schema: Dictionary, path: String) -> String:
	var props: Dictionary = schema.get("properties", {})
	for r in schema.get("required", []):
		if not obj.has(r):
			return "%s: thiếu trường '%s'" % [path, r]
	for k in obj:
		if typeof(k) != TYPE_STRING:
			return "%s: khóa không phải chuỗi" % path
		if props.has(k):
			var err := validate(obj[k], props[k], path + "." + k)
			if err != "":
				return err
		else:
			var ap: Variant = schema.get("additionalProperties", true)
			if ap is bool and ap == false:
				return "%s: trường lạ '%s'" % [path, k]
			if ap is Dictionary:
				var err2 := validate(obj[k], ap, path + "." + k)
				if err2 != "":
					return err2
	return ""


static func _validate_array(arr: Array, schema: Dictionary, path: String) -> String:
	if schema.has("minItems") and arr.size() < int(schema["minItems"]):
		return "%s: quá ít phần tử" % path
	if schema.has("maxItems") and arr.size() > int(schema["maxItems"]):
		return "%s: quá nhiều phần tử" % path
	if schema.get("uniqueItems", false):
		for i in arr.size():
			for j in range(i + 1, arr.size()):
				if _equal(arr[i], arr[j]):
					return "%s: phần tử trùng" % path
	if schema.has("items"):
		for i in arr.size():
			var err := validate(arr[i], schema["items"], "%s[%d]" % [path, i])
			if err != "":
				return err
	return ""


static func _validate_string(s: String, schema: Dictionary, path: String) -> String:
	var n := s.length()
	if schema.has("minLength") and n < int(schema["minLength"]):
		return "%s: chuỗi quá ngắn" % path
	if schema.has("maxLength") and n > int(schema["maxLength"]):
		return "%s: chuỗi quá dài" % path
	if schema.has("format") and schema["format"] == "uuid" and not is_uuid(s):
		return "%s: không phải UUID" % path
	if schema.has("pattern"):
		var re := _regex(String(schema["pattern"]))
		if re == null or re.search(s) == null:
			return "%s: không khớp mẫu" % path
	return ""


static func _validate_number(v: Variant, schema: Dictionary, path: String) -> String:
	var f := float(v)
	if is_nan(f) or is_inf(f):
		return "%s: số không hữu hạn" % path
	if schema.has("minimum") and f < float(schema["minimum"]):
		return "%s: nhỏ hơn minimum" % path
	if schema.has("maximum") and f > float(schema["maximum"]):
		return "%s: lớn hơn maximum" % path
	return ""


static func _is_type(v: Variant, t: String) -> bool:
	match t:
		"object":
			return typeof(v) == TYPE_DICTIONARY
		"array":
			return typeof(v) == TYPE_ARRAY
		"string":
			return typeof(v) == TYPE_STRING
		"boolean":
			return typeof(v) == TYPE_BOOL
		"null":
			return typeof(v) == TYPE_NIL
		"number":
			return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT
		"integer":
			if typeof(v) == TYPE_INT:
				return true
			# JSON.parse_string trả mọi số dưới dạng float
			return typeof(v) == TYPE_FLOAT and is_finite(v) and float(v) == floor(float(v)) and absf(float(v)) <= 9007199254740991.0
	return false


static func _equal(a: Variant, b: Variant) -> bool:
	var na := typeof(a) == TYPE_INT or typeof(a) == TYPE_FLOAT
	var nb := typeof(b) == TYPE_INT or typeof(b) == TYPE_FLOAT
	if na and nb:
		return float(a) == float(b)
	if typeof(a) != typeof(b):
		return false
	return a == b


static func _regex(p: String) -> RegEx:
	if not _regex_cache.has(p):
		var re := RegEx.new()
		if re.compile(p) != OK:
			_regex_cache[p] = null
		else:
			_regex_cache[p] = re
	return _regex_cache[p]


static func is_uuid(s: String) -> bool:
	if _uuid_re == null:
		_uuid_re = RegEx.new()
		_uuid_re.compile("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")
	return _uuid_re.search(s) != null
