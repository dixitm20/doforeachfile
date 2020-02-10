import json

json_data = '{"a": 1, "b": 2, "c": "manish", "d": 4, "e": 5}'

# loaded_json = json.loads(json_data)
# print(loaded_json)
# print(type(loaded_json))
# for x in loaded_json:
# 	print("%s: %s" % (x, loaded_json[x]))

parsed = json.loads(json_data)

for x in parsed:
	print("{} {}".format(x,parsed[x]))