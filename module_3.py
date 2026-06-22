def task_1(exp):

    def power(number):
        return number ** exp

    return power

power = task_1(3)
print(power(4))

def task_2(*args, **kwargs):
    for value in args:
        print(value)

    for value in kwargs.values():
        print(value)

print(task_2(1, 2, 3, moment=4, cap="arkadiy"))


def helper(func):
    def wrapper(*args, **kwargs):
        print("Hi, friend! What's your name?")

        func(*args, **kwargs)

        print("See you soon!")

    return wrapper


@helper
def task_3(name):
    print(f"Hello! My name is {name}.")

task_3("John")

import time

def timer(func):
    def wrapper(*args, **kwargs):
        start_time = time.time()

        result = func(*args, **kwargs)

        end_time = time.time()
        run_time = end_time - start_time

        print(f"Finished {func.__name__} in {run_time:.4f} secs")

        return result

    return wrapper

@timer
def task_4():
    time.sleep(2)

task_4()

def task_5(matrix):
    rows = len(matrix)
    cols = len(matrix[0])

    result = []

    for col in range(cols):
        new_row = []

        for row in range(rows):
            new_row.append(matrix[row][col])

        result.append(new_row)

    return result

print(task_5([
    [1, 2, 3],
    [4, 5, 6]
]))