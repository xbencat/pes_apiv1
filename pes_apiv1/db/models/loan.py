from sqlalchemy import Boolean, Column, DateTime, ForeignKey, Integer, SmallInteger, String, Text
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from pes_apiv1.db.base import Base


class Loan(Base):
    """Loan model for storing loan information."""

    __tablename__ = "loan"
    __table_args__ = {"schema": "public"}

    loan_id = Column(String(36), primary_key=True)
    loan_number = Column(Integer, nullable=False)
    loan_title = Column(String(50))
    loan_description = Column(Text)
    loan_type_id = Column(SmallInteger, ForeignKey("public.loan_type.loan_type_id"))
    loan_status_id = Column(SmallInteger, ForeignKey("public.loan_status.loan_status_id"))
    owner_person_id = Column(String(36), ForeignKey("public.natural_person.person_id"), nullable=False)
    created_at = Column(DateTime, server_default=func.now(), nullable=False)
    modified_at = Column(DateTime, server_default=func.now())
    modified_by = Column(String(36), ForeignKey("public.natural_person.person_id"))
    is_locked = Column(Boolean, default=False)
    notes = Column(Text)

    # Relationships (using string references to avoid circular imports)
    owner = relationship("NaturalPerson", foreign_keys=[owner_person_id], back_populates="owned_loans")
    modifier = relationship("NaturalPerson", foreign_keys=[modified_by], back_populates="modified_loans")
    loan_type = relationship("LoanType")
    loan_status = relationship("LoanStatus")
