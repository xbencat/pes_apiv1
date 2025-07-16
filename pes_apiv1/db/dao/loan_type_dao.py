from typing import List, Optional

from fastapi import Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from pes_apiv1.db.dependencies import get_db_session
from pes_apiv1.db.models.loan_type import LoanType


class LoanTypeDAO:
    """Class for accessing loan_type table."""

    def __init__(self, session: AsyncSession = Depends(get_db_session)) -> None:
        self.session = session

    async def get_all_loan_types(self) -> List[LoanType]:
        """
        Get all loan types.

        :return: list of loan type models.
        """
        raw_loan_types = await self.session.execute(select(LoanType))
        return list(raw_loan_types.scalars().fetchall())

    async def get_loan_type(self, loan_type_id: int) -> Optional[LoanType]:
        """
        Get specific loan type model.

        :param loan_type_id: id of loan type model.
        :return: loan type model.
        """
        raw_loan_type = await self.session.execute(select(LoanType).where(LoanType.loan_type_id == loan_type_id))
        return raw_loan_type.scalars().first()
