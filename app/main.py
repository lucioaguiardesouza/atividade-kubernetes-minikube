"""
App Notas - aplicação web simples (FastAPI + PostgreSQL) para a atividade de Kubernetes.

- Cadastra e lista notas no PostgreSQL.
- Mostra qual réplica (pod) atendeu a requisição, para provar o balanceamento.
- É instrumentada com OpenTelemetry (via `opentelemetry-instrument` no Dockerfile),
  que gera traces automáticos das requisições HTTP e das queries SQL.
"""
import logging
import os
import socket
import time
from contextlib import asynccontextmanager

import psycopg
from fastapi import FastAPI, Form, Request
from fastapi.responses import HTMLResponse, JSONResponse, RedirectResponse
from fastapi.templating import Jinja2Templates
from opentelemetry import trace

# ---------- Configuração (vem das variáveis de ambiente do Deployment) ----------
DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME", "notas")
DB_USER = os.getenv("DB_USER", "postgres")
DB_PASSWORD = os.getenv("DB_PASSWORD", "postgres")
POD_NAME = os.getenv("POD_NAME", socket.gethostname())

CONNINFO = f"host={DB_HOST} port={DB_PORT} dbname={DB_NAME} user={DB_USER} password={DB_PASSWORD} connect_timeout=3"

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("app-notas")


def trace_id_atual() -> str:
    """Retorna o trace_id da requisição atual (usado para ligar Logs -> Traces no Grafana)."""
    ctx = trace.get_current_span().get_span_context()
    return format(ctx.trace_id, "032x") if ctx.is_valid else "-"


def conectar():
    return psycopg.connect(CONNINFO)


def criar_tabela_com_retry(tentativas: int = 30):
    """O banco pode demorar a subir; tenta várias vezes antes de desistir."""
    for i in range(1, tentativas + 1):
        try:
            with conectar() as conn:
                conn.execute(
                    """CREATE TABLE IF NOT EXISTS notas (
                           id SERIAL PRIMARY KEY,
                           texto VARCHAR(500) NOT NULL,
                           pod VARCHAR(100) NOT NULL,
                           criado_em TIMESTAMP DEFAULT NOW()
                       )"""
                )
            log.info("tabela 'notas' pronta (banco em %s)", DB_HOST)
            return
        except Exception as e:  # noqa: BLE001
            log.warning("banco indisponivel (tentativa %d/%d): %s", i, tentativas, e)
            time.sleep(2)
    raise RuntimeError("Nao foi possivel conectar ao banco")


@asynccontextmanager
async def lifespan(_app: FastAPI):
    criar_tabela_com_retry()
    yield


app = FastAPI(title="App Notas", lifespan=lifespan)
templates = Jinja2Templates(directory=os.path.join(os.path.dirname(__file__), "templates"))


@app.middleware("http")
async def logar_requisicoes(request: Request, call_next):
    inicio = time.perf_counter()
    resposta = await call_next(request)
    if request.url.path != "/health":  # não poluir os logs com o health check
        log.info(
            "requisicao metodo=%s rota=%s status=%s duracao_ms=%.1f pod=%s trace_id=%s",
            request.method, request.url.path, resposta.status_code,
            (time.perf_counter() - inicio) * 1000, POD_NAME, trace_id_atual(),
        )
    return resposta


@app.get("/", response_class=HTMLResponse)
def index(request: Request):
    with conectar() as conn:
        notas = conn.execute(
            "SELECT id, texto, pod, criado_em FROM notas ORDER BY id DESC LIMIT 50"
        ).fetchall()
    return templates.TemplateResponse(
        request, "index.html", {"notas": notas, "pod": POD_NAME, "db_host": DB_HOST}
    )


@app.post("/notas")
def criar_nota(texto: str = Form(...)):
    with conectar() as conn:
        conn.execute("INSERT INTO notas (texto, pod) VALUES (%s, %s)", (texto[:500], POD_NAME))
    log.info("nota criada pod=%s trace_id=%s", POD_NAME, trace_id_atual())
    return RedirectResponse("/", status_code=303)


@app.get("/api/notas")
def listar_notas():
    with conectar() as conn:
        linhas = conn.execute("SELECT id, texto, pod, criado_em FROM notas ORDER BY id DESC").fetchall()
    return [{"id": l[0], "texto": l[1], "pod": l[2], "criado_em": l[3].isoformat()} for l in linhas]


@app.get("/api/info")
def info():
    """Endpoint usado no teste de balanceamento: mostra qual pod respondeu."""
    return {"pod": POD_NAME, "db_host": DB_HOST}


@app.get("/health")
def health():
    try:
        with conectar() as conn:
            conn.execute("SELECT 1")
        return {"status": "ok", "pod": POD_NAME}
    except Exception as e:  # noqa: BLE001
        return JSONResponse({"status": "erro", "detalhe": str(e)}, status_code=503)
