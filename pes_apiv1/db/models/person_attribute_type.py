from typing import List

from sqlalchemy import ARRAY, Boolean, Column, DateTime, String
from sqlalchemy.dialects.postgresql import JSONB

from pes_apiv1.db.base import Base


class PersonAttributeType(Base):
    """Person attribute type model for defining attribute schemas."""

    __tablename__ = "person_attribute_type"
    __table_args__ = {"schema": "public"}

    person_attribute_type_id = Column(String(36), primary_key=True)
    person_attribute_type_label = Column(String, nullable=False)
    person_attribute_type_datatype = Column(String, nullable=False)
    is_reference = Column(Boolean, nullable=False, default=False)
    reference_type = Column(String)
    reference_table = Column(String)
    reference_table_pk = Column(String)
    reference_table_columns: Column[List[str]] = Column(ARRAY(String))
    person_attribute_design = Column(JSONB, nullable=False, default=dict)
    is_deleted = Column(Boolean, nullable=False, default=False)
    deleted_by = Column(String(36))
    deleted_at = Column(DateTime)
