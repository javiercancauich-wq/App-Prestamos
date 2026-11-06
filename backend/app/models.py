from sqlalchemy import Column, Integer, String, Float, ForeignKey
from .database import Base
from sqlalchemy.orm import relationship

class User(Base): 
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    full_name = Column(String, nullable=False)
    email = Column(String, nullable=False, unique=True, index=True)
    hashed_password = Column(String, nullable=False)
    role = Column(String, default="client")

    loans = relationship("Loan", back_populates="owner")

class Loan(Base):
    __tablename__ = "loans"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    amount = Column(Float, nullable=False)
    status = Column(String, default="active")
    balance_remaining = Column(Float, nullable=False)

    requested_date = Column(String, nullable=True)
    disbursement_date = Column(String, nullable=True)
    start_payment_date = Column(String, nullable=True)
    term = Column(String, nullable=True)

    owner = relationship("User", back_populates="loans")
