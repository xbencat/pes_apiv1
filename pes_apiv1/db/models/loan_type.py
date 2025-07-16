from sqlalchemy import Column, SmallInteger, Text
from sqlalchemy.dialects.postgresql import JSONB

from pes_apiv1.db.base import Base


class LoanType(Base):
    """Loan type model for categorizing different types of loans."""

    __tablename__ = "loan_type"
    __table_args__ = {"schema": "public"}

    loan_type_id = Column(SmallInteger, primary_key=True)
    loan_type_label = Column(Text, nullable=False)
    loan_type_descr = Column(Text, nullable=False)
    loan_type_abbr = Column(Text)
    config = Column(JSONB, default=lambda: {"class": "badge badge-light-dark"})
