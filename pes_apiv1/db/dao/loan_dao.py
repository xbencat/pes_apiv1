from typing import List, Optional

from fastapi import Depends
from loguru import logger
from sqlalchemy import and_, select
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.ext.asyncio import AsyncSession

from pes_apiv1.db.dao.person_dao import PersonDAO
from pes_apiv1.db.dependencies import get_db_session
from pes_apiv1.db.models.loan import Loan
from pes_apiv1.db.models.loan_list import LoanList


class LoanDAO:
    """Class for accessing loan table."""

    def __init__(self, session: AsyncSession = Depends(get_db_session)) -> None:
        self.session = session

    async def get_all_loans(
        self,
        eduid: int,
        search: Optional[str] = None,
        orderby: str = "loan_number",
        orderdir: str = "asc",
    ) -> List[LoanList]:
        """
        Get all loan models for a given user.

        :param eduid: The EDUID of the user (integer identifier).
        :param search: Optional search string for loan title filtering.
        :param orderby: Column to order by (default: loan_number).
        :param orderdir: Order direction (asc or desc, default: asc).
        :return: List of loan list models.
        """
        try:
            logger.debug(f"Fetching loans for user {eduid} with search: {search}")

            # First find person by EDUID
            person_dao = PersonDAO(self.session)
            person = await person_dao.get_person_by_eduid_simple(eduid)
            if not person:
                logger.warning(f"No person found with EDUID {eduid}")
                return []

            query = select(LoanList).where(LoanList.owner_person_id == person.person_id)

            if search:
                query = query.where(LoanList.loan_title.ilike(f"%{search}%"))

            order_column = getattr(LoanList, orderby, None)
            if order_column:
                if orderdir == "desc":
                    query = query.order_by(order_column.desc())
                else:
                    query = query.order_by(order_column.asc())

            raw_loans = await self.session.execute(query)
            loans = list(raw_loans.scalars().fetchall())

            logger.info(f"Found {len(loans)} loans for user {eduid}")
            return loans

        except SQLAlchemyError as e:
            logger.error(f"Database error fetching loans for user {eduid}: {e}")
            raise
        except Exception as e:
            logger.error(f"Unexpected error fetching loans for user {eduid}: {e}")
            raise

    async def get_loan(self, loan_id: str, eduid: int) -> Optional[Loan]:
        """
        Get specific loan model for a given user.

        :param loan_id: UUID of the loan model.
        :param eduid: The EDUID of the user (integer identifier).
        :return: Loan model or None if not found.
        """
        try:
            logger.debug(f"Fetching loan {loan_id} for user {eduid}")

            # First find person by EDUID
            person_dao = PersonDAO(self.session)
            person = await person_dao.get_person_by_eduid_simple(eduid)
            if not person:
                logger.warning(f"No person found with EDUID {eduid}")
                return None

            raw_loan = await self.session.execute(
                select(Loan).where(and_(Loan.loan_id == loan_id, Loan.owner_person_id == person.person_id)),
            )

            loan = raw_loan.scalars().first()
            if loan:
                logger.info(f"Found loan {loan_id} for user {eduid}")
            else:
                logger.warning(f"Loan {loan_id} not found for user {eduid}")

            return loan

        except SQLAlchemyError as e:
            logger.error(f"Database error fetching loan {loan_id} for user {eduid}: {e}")
            raise
        except Exception as e:
            logger.error(f"Unexpected error fetching loan {loan_id} for user {eduid}: {e}")
            raise
