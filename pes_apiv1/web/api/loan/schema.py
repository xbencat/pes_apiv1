import uuid
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field, field_validator


class LoanSchema(BaseModel):
    """DTO for individual loan details."""

    loan_id: str = Field(..., description="UUID format loan identifier")
    loan_number: int = Field(..., gt=0, description="Positive loan number")
    loan_title: Optional[str] = Field(None, max_length=50, description="Loan title")
    loan_description: Optional[str] = Field(None, description="Loan description")
    loan_type_id: Optional[int] = Field(None, ge=0, description="Loan type identifier")
    loan_status_id: Optional[int] = Field(None, ge=0, description="Loan status identifier")
    owner_person_id: str = Field(..., description="UUID format person identifier")
    is_locked: Optional[bool] = None
    notes: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)

    @field_validator("loan_id", "owner_person_id")
    @classmethod
    def validate_uuid_format(cls, v: str) -> str:
        """Validate UUID format for ID fields."""
        try:
            uuid.UUID(v)
            return v
        except ValueError as e:
            raise ValueError("Must be a valid UUID format") from e


class LoanListSchema(BaseModel):
    """DTO for loan list view with denormalized data."""

    loan_id: str = Field(..., description="UUID format loan identifier")
    loan_number: int = Field(..., gt=0, description="Positive loan number")
    loan_title: Optional[str] = Field(None, max_length=50, description="Loan title")
    loan_type_label: Optional[str] = None
    loan_status_label: Optional[str] = None
    referent_first_name: Optional[str] = Field(None, max_length=100)
    referent_last_name: Optional[str] = Field(None, max_length=100)
    guarantor_first_name: Optional[str] = Field(None, max_length=100)
    guarantor_last_name: Optional[str] = Field(None, max_length=100)
    loan_amount: Optional[float] = Field(None, ge=0, description="Non-negative loan amount")
    loan_amount_unpaid: Optional[float] = Field(None, ge=0, description="Non-negative unpaid amount")
    loan_due_date: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)

    @field_validator("loan_id")
    @classmethod
    def validate_loan_id_uuid(cls, v: str) -> str:
        """Validate UUID format for loan ID."""
        try:
            uuid.UUID(v)
            return v
        except ValueError as e:
            raise ValueError("Must be a valid UUID format") from e
