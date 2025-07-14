from sqlalchemy.orm import DeclarativeBase

from pes_apiv1.db.meta import meta


class Base(DeclarativeBase):
    """Base for all models."""

    metadata = meta
