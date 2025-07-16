from sqlalchemy import Boolean, Column, DateTime, Float, ForeignKey, Integer, SmallInteger, String, Text

from pes_apiv1.db.base import Base


class LoanList(Base):
    """Loan list view model for denormalized loan data."""

    __tablename__ = "loan_list"
    __table_args__ = {"schema": "public"}

    loan_id = Column(String(36), primary_key=True)
    loan_number = Column(Integer)
    loan_title = Column(String(50))
    loan_description = Column(Text)
    loan_type_id = Column(SmallInteger, ForeignKey("public.loan_type.loan_type_id"))
    loan_type_label = Column(Text)
    loan_type_descr = Column(Text)
    loan_status_id = Column(SmallInteger, ForeignKey("public.loan_status.loan_status_id"))
    loan_status_label = Column(Text)
    loan_status_descr = Column(Text)
    owner_person_id = Column(String(36), ForeignKey("public.natural_person.person_id"))
    owner_first_name = Column(String(100))
    owner_last_name = Column(String(100))
    assessor_person_id = Column(String(36), ForeignKey("public.natural_person.person_id"))
    assessor_first_name = Column(String(100))
    assessor_last_name = Column(String(100))
    guarantor_person_id = Column(String(36), ForeignKey("public.natural_person.person_id"))
    guarantor_first_name = Column(String(100))
    guarantor_last_name = Column(String(100))
    loan_objective_attr_numeric = Column(Text)
    loan_objective_attr_text = Column(Text)
    loan_objective_attr_time = Column(Text)
    loan_objective_attr_json = Column(Text)
    created_at = Column(DateTime)
    modified_at = Column(DateTime)
    modified_by = Column(String(36), ForeignKey("public.natural_person.person_id"))
    modified_by_first_name = Column(String(100))
    modified_by_last_name = Column(String(100))
    is_locked = Column(Boolean)
    notes = Column(Text)
    loan_amount = Column(Float)
    currency = Column(Text)
    due_date = Column(Text)
    is_installment_calendar = Column(Boolean)
    principal_amount = Column(Float)
    principal_balance = Column(Float)
    overdue_amount = Column(Float)
