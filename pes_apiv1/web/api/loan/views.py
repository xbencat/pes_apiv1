from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query

from pes_apiv1.db.dao.loan_dao import LoanDAO
from pes_apiv1.db.models.loan_list import LoanList
from pes_apiv1.web.api.loan.schema import LoanListSchema, LoanSchema

router = APIRouter(
    prefix="/loans",
    tags=["Loans"],
    responses={404: {"description": "Not found"}},
)


@router.get(
    "",
    response_model=List[LoanListSchema],
    summary="Get all loans",
    description="Retrieve all loan objects for a user identified by EDUID",
)
async def get_loans(
    eduid: int = Query(...),
    search: Optional[str] = None,
    orderby: str = Query(
        "loan_number",
        enum=[
            "loan_number",
            "loan_title",
            "loan_type_label",
            "loan_status_label",
            "referent_first_name",
            "referent_last_name",
            "guarantor_first_name",
            "guarantor_last_name",
            "loan_amount",
            "loan_amount_unpaid",
            "loan_due_date",
        ],
    ),
    orderdir: str = Query("asc", enum=["asc", "desc"]),
    loan_dao: LoanDAO = Depends(),
) -> List[LoanListSchema]:
    """
    Retrieve all loan objects from the database.

    :param eduid: The EDUID of the user (integer identifier).
    :param search: Optional search string for loan title filtering.
    :param orderby: Column to order by (loan_number, loan_title, etc.).
    :param orderdir: Order direction (asc or desc).
    :param loan_dao: DAO for loan models.
    :return: List of loan list objects from database.
    """
    try:
        loans: List[LoanList] = await loan_dao.get_all_loans(
            eduid=eduid,
            search=search,
            orderby=orderby,
            orderdir=orderdir,
        )
        return [LoanListSchema.model_validate(loan) for loan in loans]
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to retrieve loans: {e!s}") from e


@router.get(
    "/{loan_id}",
    response_model=LoanSchema,
    summary="Get loan by ID",
    description="Retrieve a specific loan object by its ID for a user identified by EDUID",
)
async def get_loan(
    loan_id: str,
    eduid: int = Query(...),
    loan_dao: LoanDAO = Depends(),
) -> LoanSchema:
    """
    Retrieve specific loan object from the database.

    :param loan_id: UUID of the loan object.
    :param eduid: The EDUID of the user (integer identifier).
    :param loan_dao: DAO for loan models.
    :return: Loan object from database.
    """
    try:
        loan = await loan_dao.get_loan(loan_id=loan_id, eduid=eduid)
        if not loan:
            raise HTTPException(status_code=404, detail="Loan not found")
        return LoanSchema.model_validate(loan)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to retrieve loan: {e!s}") from e
