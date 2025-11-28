# ---------------------------------------------
# Paquexpress - API mínima en un solo archivo
# FastAPI + SQLAlchemy + JWT + Uploads
# ---------------------------------------------
import os
from fastapi import FastAPI, UploadFile, File, Form, Request, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from datetime import datetime, timedelta
from passlib.context import CryptContext
from jose import jwt, JWTError
from sqlalchemy import create_engine, Column, Integer, String, Enum, Float, ForeignKey
from sqlalchemy.orm import sessionmaker, declarative_base
from fastapi import status

# --------------------------
# CONFIG
# --------------------------
SECRET_KEY = "PAQUEXPRESS_SUPER_SECRETO"
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60

DATABASE_URL = "mysql+pymysql://root:root@localhost/paquexpress"

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# --------------------------
# DB SETUP
# --------------------------
engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(bind=engine)
Base = declarative_base()

# --------------------------
# MODELOS BD
# --------------------------
class Usuario(Base):
    __tablename__ = "usuarios"
    id = Column(Integer, primary_key=True)
    nombre = Column(String(120))
    email = Column(String(150), unique=True)
    password_hash = Column(String(255))
    rol = Column(Enum("agente","admin"), default="agente")

class Paquete(Base):
    __tablename__ = "paquetes"
    id = Column(Integer, primary_key=True)
    referencia = Column(String(100), unique=True)
    direccion = Column(String(255))
    lat_destino = Column(Float)
    lon_destino = Column(Float)
    agente_asignado = Column(Integer, ForeignKey("usuarios.id"))
    estado = Column(Enum("pendiente","en_ruta","entregado"), default="pendiente")

class Entrega(Base):
    __tablename__ = "entregas"
    id = Column(Integer, primary_key=True)
    paquete_id = Column(Integer, ForeignKey("paquetes.id"))
    agente_id = Column(Integer, ForeignKey("usuarios.id"))
    foto_url = Column(String(255))
    lat_gps = Column(Float)
    lon_gps = Column(Float)

Base.metadata.create_all(bind=engine)

# --------------------------
# Pydantic Models
# --------------------------
class LoginResponse(BaseModel):
    token: str
    agentId: int

# --------------------------
# JWT
# --------------------------
def create_access_token(data: dict):
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)


# --------------------------
# FASTAPI
# --------------------------
app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# --------------------------
# LOGIN
# --------------------------
@app.post("/login", response_model=LoginResponse)
async def login(request: Request):
    db = SessionLocal()
    data = await request.json()

    email = data.get("email")
    password = data.get("password")

    # Si la contraseña es muy larga → trúncala
    if len(password.encode("utf-8")) > 72:
        password = password[:72]

    user = db.query(Usuario).filter(Usuario.email == email).first()

    if not user:
        raise HTTPException(status_code=401, detail="Email no encontrado")

    if not pwd_context.verify(password, user.password_hash):
        raise HTTPException(status_code=401, detail="Contraseña incorrecta")

    token_data = {"sub": user.email, "id": user.id, "rol": user.rol}
    token = create_access_token(token_data)

    return LoginResponse(token=token, agentId=user.id)


# --------------------------
# LISTA DE PAQUETES
# --------------------------
@app.get("/paquetes/{agente_id}")
def get_paquetes(agente_id: int):
    db = SessionLocal()
    paqs = db.query(Paquete).filter(
        Paquete.agente_asignado == agente_id,
        Paquete.estado != "entregado"
    ).all()
    return paqs


# --------------------------
# REGISTRAR ENTREGA
# --------------------------
@app.post("/entregar")
async def entregar(
    paquete_id: int = Form(...),
    agente_id: int = Form(...),
    lat_gps: float = Form(...),
    lon_gps: float = Form(...),
    foto: UploadFile = File(...)
):
    db = SessionLocal()

    # Guardar foto
    if not os.path.exists("uploads"):
        os.makedirs("uploads")

    filename = f"{datetime.now().timestamp()}_{foto.filename}"
    file_path = os.path.join("uploads", filename)

    with open(file_path, "wb") as buffer:
        buffer.write(await foto.read())

    # Crear registro
    entrega = Entrega(
        paquete_id=paquete_id,
        agente_id=agente_id,
        lat_gps=lat_gps,
        lon_gps=lon_gps,
        foto_url=file_path,
    )
    db.add(entrega)

    # Marcar paquete entregado
    paquete = db.query(Paquete).filter(Paquete.id == paquete_id).first()
    paquete.estado = "entregado"

    db.commit()

    return {"message": "Entrega registrada", "foto": file_path}
