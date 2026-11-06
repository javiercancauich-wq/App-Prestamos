from fastapi import FastAPI, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from pydantic import BaseModel
from .database import engine, get_db
from . import models
from typing import Optional

# Crea las tablas en la base de datos si no existen
models.Base.metadata.create_all(bind=engine)

app = FastAPI(title="Sistema de Préstamos API", version="1.0")

# --- ESQUEMAS DE DATOS (Pydantic) ---
class UserCreate(BaseModel):
    full_name: str
    email: str
    password: str
    role: str = "client" # 'admin' o 'client'

class UserLogin(BaseModel):
    email: str
    password: str

class UserResponse(BaseModel):
    id: int
    full_name: str
    email: str
    role: str

    class Config:
        from_attributes = True

class LoanCreate(BaseModel):
    user_id: int
    amount: float
    balance_remaining: float
    requested_date: str
    disbursement_date: str
    start_payment_date: str
    term: str

class LoanResponse(BaseModel):
    id: int
    user_id: int
    amount: float
    balance_remaining: float
    status: str


    requested_date: Optional[str] = None
    disbursement_date: Optional[str] = None
    start_payment_date: Optional[str] = None
    term: Optional[str] = None

    class Config:
        from_attributes = True

# --- RUTAS DE LA API ---

@app.get("/")
def read_root():
    return {"message": "¡El servidor de préstamos está activo y funcionando!"}

# 1. Registrar un nuevo usuario
@app.post("/users/", response_model=UserResponse)
def create_user(user: UserCreate, db: Session = Depends(get_db)):
    db_user = db.query(models.User).filter(models.User.email == user.email).first()
    if db_user:
        raise HTTPException(status_code=400, detail="El correo ya está registrado")
    
    new_user = models.User(
        full_name=user.full_name,
        email=user.email,
        hashed_password=user.password,
        role=user.role
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    return new_user

# 2. Iniciar Sesión (Login)
@app.post("/login/")
def login_user(user_login: UserLogin, db: Session = Depends(get_db)):
    # Buscamos al usuario por correo
    user = db.query(models.User).filter(models.User.email == user_login.email).first()
    
    # Validamos si existe y si la contraseña coincide
    if not user or user.hashed_password != user_login.password:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Correo o contraseña incorrectos"
        )
    
    # Retornamos los datos clave, incluyendo su rol ('admin' o 'client')
    return {
        "message": "Inicio de sesión exitoso",
        "user_id": user.id,
        "full_name": user.full_name,
        "role": user.role
    }

# 3. Listar todos los usuarios
@app.get("/users/", response_model=List[UserResponse])
def get_users(db: Session = Depends(get_db)):
    return db.query(models.User).all()

# 4. Crear un préstamo
@app.post("/loans/", response_model=LoanResponse)
def create_loan(loan: LoanCreate, db: Session = Depends(get_db)):
    new_loan = models.Loan(
        user_id=loan.user_id,
        amount=loan.amount,
        balance_remaining=loan.balance_remaining,
        status="active", # Estado por defecto
        requested_date=loan.requested_date,
        disbursement_date=loan.disbursement_date,
        start_payment_date=loan.start_payment_date,
        term=loan.term
    )
    db.add(new_loan)
    db.commit()
    db.refresh(new_loan)
    return new_loan

# 5. Ver todos los préstamos
@app.get("/loans/", response_model=List[LoanResponse])
def get_loans(db: Session = Depends(get_db)):
    return db.query(models.Loan).all()


# 6. Ver los prestamos de un usuario especifico
@app.get("/loans/users/{user_id}", response_model=List[LoanResponse])
def get_user_loans(user_id: int, db: Session = Depends(get_db)):
    loans = db.query(models.Loan).filter(models.Loan.user_id == user_id).all()
    return loans