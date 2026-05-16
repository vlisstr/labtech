# Лабораторна робота №2 — дослідницька частина

Артефакти експериментів з контейнеризацією, на які посилається [звіт](../report.docx).

Практична частина (`docker-compose.yml` для застосунку з Лаб №1) знаходиться в окремому репозиторії: [mywebapp-lab1](../mywebapp-lab1) (заміни на свій URL).

## Структура

```
.
├── README.md
├── python/                   — експерименти 1-5 з Python-застосунком
│   ├── README.md             — команди для кожного експерименту
│   ├── exp1-naive/Dockerfile     — naive (поганий) Dockerfile
│   ├── exp3-layered/Dockerfile   — оптимізований шарами
│   ├── exp4-alpine/Dockerfile    — alpine-base
│   └── exp5-numpy/
│       ├── Dockerfile.debian     — numpy на Debian (швидко)
│       ├── Dockerfile.alpine     — numpy на Alpine (компіляція)
│       └── matrix_endpoint.py    — новий ендпоінт /matrix
├── musl-vs-glibc/            — експеримент з DNS-резолвом
│   └── README.md             — команди + аналіз
└── golang/                   — multi-stage build експерименти
    ├── README.md             — команди + порівняльна таблиця
    ├── exp1-naive/Dockerfile     — single-stage (велике)
    ├── exp2-scratch/Dockerfile   — multi-stage + FROM scratch
    └── exp3-distroless/Dockerfile — multi-stage + distroless
```

## Як відтворити

Кожен підкаталог містить власний `README.md` з покроковими командами для відтворення експериментів. Стартові проекти беруться з GitHub (URL у відповідних README), Dockerfile-и копіюються в корінь стартового проекту, і потім запускаються команди `docker build` + `docker images` для виміру часу та розміру.

Стенд для вимірів — згідно зі звітом (вказані ОС хоста, версія Docker та ресурси).
