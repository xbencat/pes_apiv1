from typing import List, Optional

from fastapi import Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from pes_apiv1.db.dependencies import get_db_session
from pes_apiv1.db.models.loan_status import LoanStatus


class LoanStatusDAO:
    """Class for accessing loan_status table."""

    def __init__(self, session: AsyncSession = Depends(get_db_session)) -> None:
        self.session = session

    async def get_all_loan_statuses(self) -> List[LoanStatus]:
        """
        Get all loan statuses.

        :return: list of loan status models.
        """
        raw_loan_statuses = await self.session.execute(select(LoanStatus))
        return list(raw_loan_statuses.scalars().fetchall())

    async def get_loan_status(self, loan_status_id: int) -> Optional[LoanStatus]:
        """
        Get specific loan status model.

        :param loan_status_id: id of loan status model.
        :return: loan status model.
        """
        raw_loan_status = await self.session.execute(
            select(LoanStatus).where(LoanStatus.loan_status_id == loan_status_id),
        )
        return raw_loan_status.scalars().first()
