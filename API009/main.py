# ---------------------------------------------
# Paquexpress - API INTEGRADA Y SIN ENCRIPTACIÓN
# FastAPI + SQLAlchemy + JWT + Uploads
# ---------------------------------------------
import os
import shutil # Necesario para la subida de archivos del proyecto anterior
from fastapi import FastAPI, UploadFile, File, Form, Request, HTTPException
from fastapi.staticfiles import StaticFiles # Necesario para montar la carpeta uploads
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from datetime import datetime, timedelta
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
    # Contraseña en texto plano para desarrollo (SIN ENCRIPTACIÓN)
    password = Column(String(255)) 
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

# AÑADIDO: Monta la carpeta 'uploads' para que las imágenes sean accesibles
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# --------------------------
# LOGIN (SIN ENCRIPTACIÓN)
# --------------------------
@app.post("/login", response_model=LoginResponse)
async def login(request: Request):
    db = SessionLocal()
    data = await request.json()

    email = data.get("email")
    password = data.get("password")

    user = db.query(Usuario).filter(Usuario.email == email).first()

    if not user:
        raise HTTPException(status_code=401, detail="Email no encontrado")

    # Comparación de contraseña en texto plano
    if password != user.password: 
        raise HTTPException(status_code=401, detail="Contraseña incorrecta")

    token_data = {"sub": user.email, "id": user.id, "rol": user.rol}
    token = create_access_token(token_data)

    # La API ahora devuelve "agentId" en la respuesta, que Flutter guarda
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
    db.close()
    return paqs


# --------------------------
# REGISTRAR ENTREGA (LÓGICA DE SUBIDA DE ARCHIVOS DE TU API ANTERIOR)
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

    try:
        # 1. Preparar la carpeta y la ruta del archivo
        os.makedirs("uploads", exist_ok=True)
        # Usamos el timestamp para asegurar un nombre de archivo único
        filename = f"{datetime.now().timestamp()}_{foto.filename}"
        file_path = os.path.join("uploads", filename)
        
        # 2. Guardar foto usando la lógica de shutil.copyfileobj (más eficiente)
        with open(file_path, "wb") as buffer:
             # Copia los datos binarios del archivo subido al archivo local
            shutil.copyfileobj(foto.file, buffer) 

        # 3. Crear registro de Entrega
        # La URL que la app Flutter usará será '/uploads/nombre_archivo.jpg'
        foto_url_publica = f"/uploads/{filename}"

        entrega = Entrega(
            paquete_id=paquete_id,
            agente_id=agente_id,
            lat_gps=lat_gps,
            lon_gps=lon_gps,
            foto_url=foto_url_publica, # Guarda la URL pública para mostrar la foto
        )
        db.add(entrega)

        # 4. Marcar paquete entregado
        paquete = db.query(Paquete).filter(Paquete.id == paquete_id).first()
        if paquete:
            paquete.estado = "entregado"

        db.commit()

        return {"message": "Entrega registrada", "foto_url": foto_url_publica}
    
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Error al registrar la entrega: {str(e)}")
    
    finally:
        db.close()