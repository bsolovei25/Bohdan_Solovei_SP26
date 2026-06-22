def find_pair(numbers, target):
    seen = set()

    for num in numbers:
        complement = target - num

        if complement in seen:
            return [complement, num]

        seen.add(num)

    return []


sample = [3, 4, -1, 10, 12]
target = 2

print(find_pair(sample, target))

def reverse_number(n):
    reversed_num = 0

    while n > 0:
        digit = n % 10
        reversed_num = reversed_num * 10 + digit
        n //= 10

    return reversed_num

sample = 130
print(reverse_number(sample))


def first_duplicate(nums):
    for num in nums:
        idx = abs(num) - 1

        if nums[idx] < 0:
            return abs(num)

        nums[idx] = -nums[idx]

    return -1


sample = [2, 1, 3, 4, 2]

print(first_duplicate(sample))


def roman_to_int(s):
    values = {
        'I': 1,
        'V': 5,
        'X': 10,
        'L': 50,
        'C': 100,
        'D': 500,
        'M': 1000
    }

    result = 0

    for i in range(len(s)):
        current = values[s[i]]

        if i < len(s) - 1 and current < values[s[i + 1]]:
            result -= current
        else:
            result += current

    return result


sample = "XIX"

print(roman_to_int(sample))

def find_min(nums):
    smallest = nums[0]

    for num in nums:
        if num < smallest:
            smallest = num

    return smallest


print(find_min([3, 4, -1, 10, 12]));