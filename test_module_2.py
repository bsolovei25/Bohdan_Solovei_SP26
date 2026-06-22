def task_1(dict1, dict2):
    result = dict1.copy()

    for key, value in dict2.items():
        if key in result:
            result[key] += value
        else:
            result[key] = value

    return result

print(task_1({'a': 123, 'b': 23, 'c': 0}, {'a': 1, 'b': 11, 'd': 99}))

def task_2():
    result = {}

    for i in range(1, 16):
        result[i] = i * i

    return result

print(task_2())

def task_3(data):
    result = ['']

    for letters in data.values():
        new_result = []

        for prefix in result:
            for letter in letters:
                new_result.append(prefix + letter)

        result = new_result

    return result

data = {
    '1': ['a', 'b'],
    '2': ['c', 'd']
}

print(task_3(data))

def task_4(data):
    sorted_items = sorted(data.items(), key=lambda item: item[1], reverse=True)
    return [key for key, value in sorted_items[:3]]

print(task_4({
    'a': 500,
    'b': 5874,
    'c': 560,
    'd': 400,
    'e': 5874,
    'f': 20
}))

def task_5(pairs):
    result = {}

    for key, value in pairs:
        if key not in result:
            result[key] = []

        result[key].append(value)

    return result

print(task_5([
    ('yellow', 1),
    ('blue', 2),
    ('yellow', 3),
    ('blue', 4),
    ('red', 1)
]))

def task_6(items):
    result = []

    for item in items:
        if item not in result:
            result.append(item)

    return result

print(task_6([1, 1, 3, "3"]))

def task_7(words):
    if not words:
        return ""

    prefix = words[0]

    for word in words[1:]:
        while not word.startswith(prefix):
            prefix = prefix[:-1]

            if prefix == "":
                return ""

    return prefix


print(task_7(["flower", "flows"]))