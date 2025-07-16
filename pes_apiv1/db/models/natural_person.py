from sqlalchemy import Boolean, Column, Date, DateTime, String
from sqlalchemy.dialects.postgresql import JSON
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from pes_apiv1.db.base import Base


class NaturalPerson(Base):
    """Natural person model for storing individual person information."""

    __tablename__ = "natural_person"
    __table_args__ = {"schema": "public"}

    person_id = Column(String(36), primary_key=True)
    personal_identification_number = Column(String(10), nullable=False)  # RC
    first_name = Column(String(100))
    last_name = Column(String(100))
    title_before = Column(String(15))
    title_after = Column(String(15))
    date_of_birth = Column(Date, nullable=False)
    nationality = Column(String, nullable=False)
    address = Column(String, nullable=False)
    correspondence_address = Column(String)
    email = Column(String)
    phone_number = Column(String)
    created_at = Column(DateTime, server_default=func.now())
    last_modified = Column(DateTime, server_default=func.now())
    preference = Column(JSON)
    is_service_account = Column(Boolean, default=False)

    # Relationships
    owned_loans = relationship("Loan", foreign_keys="Loan.owner_person_id", back_populates="owner")
    modified_loans = relationship("Loan", foreign_keys="Loan.modified_by", back_populates="modifier")
    attributes = relationship("NaturalPersonAttribute", foreign_keys="NaturalPersonAttribute.person_id")
