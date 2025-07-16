from sqlalchemy import Column, SmallInteger, Text

from pes_apiv1.db.base import Base


class LoanStatus(Base):
    """Loan status model for categorizing loan states."""

    __tablename__ = "loan_status"
    __table_args__ = {"schema": "public"}

    loan_status_id = Column(SmallInteger, primary_key=True)
    loan_status_label = Column(Text, nullable=False)
    loan_status_descr = Column(Text, nullable=False)
