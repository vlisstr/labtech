# Python — experiments 1-5

Starter project: <https://github.com/KPI-FICT-MTSD/lab-03-starter-project-python>

Before running anything below, clone the starter project to some working
directory and `cd` into it.

To make builds reproducible, we freeze dependency versions. Generate a
locked `requirements.txt` once:

```bash
python -m venv .venv && . .venv/bin/activate
pip install fastapi uvicorn        # base deps from the starter project
pip freeze > requirements.txt
```

For experiment 5 also add `numpy` to the freeze:

```bash
pip install numpy
pip freeze > requirements.txt
```

## Experiment 1 — baseline (naive Dockerfile)

Copy `exp1-naive/Dockerfile` into the project root, then:

```bash
docker pull python:3.13-bookworm

time docker build --no-cache --pull=false -t pyexp:1 .

docker images pyexp:1 --format '{{.Size}}'
```

## Experiment 2 — rebuild after code change

Edit one line in `spaceship/app.py` (e.g. add `# touched` somewhere), then:

```bash
time docker build -t pyexp:2 .
docker images pyexp:2 --format '{{.Size}}'
```

The size should be ~identical; the time should show whether your cache is
helping or not. With the naive Dockerfile it isn't — `pip install` re-runs.

## Experiment 3 — proper layering

Replace the Dockerfile with `exp3-layered/Dockerfile`. Repeat 1+2:

```bash
time docker build --no-cache --pull=false -t pyexp:3a .

echo "# touched" >> spaceship/app.py
time docker build -t pyexp:3b .
```

Compare the second-rebuild time with experiment 2's rebuild time. That's
the whole lesson.

## Experiment 4 — Alpine base

```bash
docker pull python:3.13-alpine
cp exp4-alpine/Dockerfile ./Dockerfile
time docker build --no-cache --pull=false -t pyexp:4 .
docker images pyexp:4 --format '{{.Size}}'
```

## Experiment 5 — adding numpy

1. Add the new endpoint from `exp5-numpy/matrix_endpoint.py` to
   `spaceship/routers/api.py`.
2. Add numpy to requirements.txt:

   ```bash
   pip install numpy
   pip freeze > requirements.txt
   ```

3. Build both variants:

   ```bash
   # Debian — numpy installs from a manylinux wheel, fast.
   cp exp5-numpy/Dockerfile.debian ./Dockerfile
   time docker build --no-cache --pull=false -t pyexp:5-debian .
   docker images pyexp:5-debian --format '{{.Size}}'

   # Alpine — numpy compiles from source. Grab a coffee.
   cp exp5-numpy/Dockerfile.alpine ./Dockerfile
   time docker build --no-cache --pull=false -t pyexp:5-alpine .
   docker images pyexp:5-alpine --format '{{.Size}}'
   ```

Record both build times and both final image sizes for the report. The
Alpine version is meaningfully slower and surprisingly close in size to
the Debian one, despite Alpine's reputation for being small. That is the
lesson.
