
class Trainee:
    def __init__(self, name, surname):
        self.name = name;
        self.surname = surname;
        self.visited_lectures = 0
        self.done_home_tasks = 0
        self.missed_lectures = 0
        self.missed_home_tasks = 0
        self.mark = 0
    def visit_lecture(self):
        self.visited_lectures += 1
        self._add_points(1)
    def do_homework(self):
        self.done_home_tasks += 2
        self._add_points(2)
    def miss_lecture(self):
        self.missed_lectures -= 1
        self._subtract_points(1)
    def missed_homework(self):
        self.missed_home_tasks -= 2
        self._subtract_points(2)
    def _add_points(self, points):
        self.mark += points
        if self.mark > 10:
            self.mark = 10
    def _subtract_points(self, points):
        self.mark -= points;
        if self.mark < 0:
            self.mark = 0
            
    def is_passed(self):
        if self.mark >= 8:
            print('Good job!')
        else:
            print(f'You need to get {8-self.mark} more points. Try to do your best!')


t = Trainee("John", "Smith")

print(t.name)
print(t.surname)
print(t.visited_lectures)
t.visit_lecture()
t.visit_lecture()
print(t.visited_lectures)
print(t.done_home_tasks)

t.do_homework()
t.do_homework()
print(t.done_home_tasks)

print(t.missed_home_tasks)

t.miss_lecture()
t.miss_lecture()
print(t.missed_home_tasks)

