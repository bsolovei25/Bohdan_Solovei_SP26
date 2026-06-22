from random import choice
import requests
from requests.exceptions import RequestException
def task_1() :
    with open('names.txt', 'r', encoding='utf-8') as f1:
        names = [line.strip().lower() for line in f1]

    with open('last_names.txt', 'r', encoding='utf-8') as f2:
        surname = [line.strip().lower() for line in f2]

    names.sort()

    with open('sorted_names_and_surnames.txt', 'w', encoding='utf-8') as f3:
        for name in names:
            f3.write(f"{name} {choice(surname)}\n")

def task_2(top_k):
    result = []

    with open('stop_words.txt', 'r', encoding='utf-8') as stop:
        stop_words = stop.read().split()

    with open("random_text.txt", 'r', encoding='utf-8') as f1:
        rand_text = f1.read()

    freq = {}

    for word in rand_text.split():
        word = word.lower()

        if word not in stop_words:
            if word in freq:
                freq[word] += 1
            else:
                freq[word] = 1

    top_words = sorted(freq.items(), key=lambda x: x[1], reverse=True)

    for item in top_words[:top_k]:
        result.append(item)

    return result

print(task_2(3))



def task_3(url):
    try:
        response = requests.get(url)
        response.raise_for_status()
        return response

    except RequestException:
        raise RequestException


print(task_3('https://www.epam.com/'))

def task_4(data):
    try:
        return sum(data)

    except TypeError:
        total = 0

        for item in data:
            if isinstance(item, str):
                total += float(item)
            else:
                total += item

        return total

print(task_4([1,'2',3]))


def task_5():
    try:
        v1, v2 = input().split()

        v1 = float(v1)
        v2 = float(v2)

        result = v1 / v2

        if result.is_integer():
            print(int(result))
        else:
            print(round(result, 3))

    except ZeroDivisionError:
        print("Can't divide by zero")

    except ValueError:
        print("Entered value is wrong")


print(task_5())