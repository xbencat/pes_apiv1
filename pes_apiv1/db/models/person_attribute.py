from sqlalchemy import Boolean, Column, DateTime, ForeignKey, String
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from pes_apiv1.db.base import Base


class NaturalPersonAttribute(Base):
    """Natural person attribute model for storing dynamic person attributes."""

    __tablename__ = "natural_person_attribute"
    __table_args__ = {"schema": "public"}

    person_id = Column(String(36), ForeignKey("public.natural_person.person_id"), primary_key=True)
    person_attribute_type_id = Column(
        String(36),
        ForeignKey("public.person_attribute_type.person_attribute_type_id"),
        primary_key=True,
    )
    valid_from = Column(DateTime, primary_key=True, server_default=func.now())
    valid_to = Column(DateTime)
    created_by = Column(String(36), ForeignKey("public.natural_person.person_id"), nullable=False)
    deleted_by = Column(String(36), ForeignKey("public.natural_person.person_id"))
    attribute_value = Column(JSONB, nullable=False, default=lambda: {"value": 0})

    # Relationships
    person = relationship("NaturalPerson", foreign_keys=[person_id])
    attribute_type = relationship("PersonAttributeType")
    creator = relationship("NaturalPerson", foreign_keys=[created_by])
    deleter = relationship("NaturalPerson", foreign_keys=[deleted_by])


class PersonAttributeListView(Base):
    """Person attribute list view model for denormalized attribute data."""

    __tablename__ = "person_attribute_list_all"
    __table_args__ = {"schema": "public"}

    person_id = Column(String(36), primary_key=True)
    attribute_type_id = Column(String(36), primary_key=True)
    valid_from = Column(DateTime, primary_key=True)
    valid_to = Column(DateTime)
    created_by = Column(String(36))
    attribute_label = Column(String)
    attribute_datatype = Column(String)
    attribute_design = Column(JSONB)
    attribute_value = Column(JSONB)
    is_reference = Column(Boolean)
    reference_type = Column(String)
