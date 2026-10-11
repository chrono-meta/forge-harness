import json, sys, os
DB = os.environ.get("TODO_DB", "todo.json")
def load():
    return json.load(open(DB)) if os.path.exists(DB) else []
def save(items): json.dump(items, open(DB, "w"))
def add(t): i=load(); i.append({"t":t,"done":False}); save(i)
def done(n): i=load(); i[n]["done"]=True; save(i)
def main(a):
    if a[0]=="add": add(" ".join(a[1:]))
    elif a[0]=="done": done(int(a[1]))
    elif a[0]=="list":
        for n,x in enumerate(load()): print(n, "x" if x["done"] else " ", x["t"])
if __name__=="__main__": main(sys.argv[1:])
