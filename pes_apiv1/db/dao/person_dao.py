from typing import Optional

from fastapi import Depends
from sqlalchemy import and_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from pes_apiv1.db.dependencies import get_db_session
from pes_apiv1.db.models.natural_person import NaturalPerson
from pes_apiv1.db.models.person_attribute import NaturalPersonAttribute, PersonAttributeListView


class PersonDAO:
    """DAO for person-related operations."""

    def __init__(self, session: AsyncSession = Depends(get_db_session)) -> None:
        self.session = session

    async def get_person_by_eduid(self, eduid: int) -> Optional[NaturalPerson]:
        """Get person by EDUID from attributes using relationships."""
        # Use relationships to find person by EDUID attribute
        stmt = (
            select(NaturalPerson)
            .join(NaturalPersonAttribute, NaturalPerson.person_id == NaturalPersonAttribute.person_id)
            .join(NaturalPersonAttribute.attribute_type)
            .where(
                and_(
                    NaturalPersonAttribute.attribute_type.has(person_attribute_type_label="EDUID"),
                    NaturalPersonAttribute.attribute_value["value"].astext == str(eduid),
                    NaturalPersonAttribute.valid_to.is_(None),
                ),
            )
            .options(selectinload(NaturalPerson.attributes), selectinload(NaturalPerson.owned_loans))
        )

        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_person_by_eduid_simple(self, eduid: int) -> Optional[NaturalPerson]:
        """Get person by EDUID using the view (simpler, faster approach)."""
        # First find person_id by EDUID using the view
        stmt = select(PersonAttributeListView).where(
            and_(
                PersonAttributeListView.attribute_label == "EDUID",
                PersonAttributeListView.attribute_value["value"].astext == str(eduid),
                PersonAttributeListView.valid_to.is_(None),
            ),
        )
        result = await self.session.execute(stmt)
        attr = result.scalar_one_or_none()

        if not attr:
            return None

        # Then get the person with relationships
        person_stmt = (
            select(NaturalPerson)
            .where(NaturalPerson.person_id == attr.person_id)
            .options(selectinload(NaturalPerson.owned_loans), selectinload(NaturalPerson.attributes))
        )
        person_result = await self.session.execute(person_stmt)
        return person_result.scalar_one_or_none()

    async def get_person_by_details(
        self,
        first_name: str,
        last_name: str,
        personal_identification_number: str,
        date_of_birth: str,
    ) -> Optional[NaturalPerson]:
        """Get person by personal details (alternative to EDUID lookup)."""
        stmt = select(NaturalPerson).where(
            and_(
                NaturalPerson.first_name == first_name,
                NaturalPerson.last_name == last_name,
                NaturalPerson.personal_identification_number == personal_identification_number,
                NaturalPerson.date_of_birth == date_of_birth,
            ),
        )
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()
