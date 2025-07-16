"""pes_apiv1 models."""

import pkgutil
from pathlib import Path

from pes_apiv1.db.models.loan import Loan
from pes_apiv1.db.models.loan_list import LoanList
from pes_apiv1.db.models.loan_status import LoanStatus
from pes_apiv1.db.models.loan_type import LoanType

# Import all models explicitly to ensure proper loading order
from pes_apiv1.db.models.natural_person import NaturalPerson
from pes_apiv1.db.models.person_attribute import NaturalPersonAttribute, PersonAttributeListView
from pes_apiv1.db.models.person_attribute_type import PersonAttributeType

__all__ = [
    "NaturalPerson",
    "PersonAttributeType",
    "NaturalPersonAttribute",
    "PersonAttributeListView",
    "LoanType",
    "LoanStatus",
    "Loan",
    "LoanList",
]


def load_all_models() -> None:
    """Load all models from this folder."""
    package_dir = Path(__file__).resolve().parent
    modules = pkgutil.walk_packages(
        path=[str(package_dir)],
        prefix="pes_apiv1.db.models.",
    )
    for module in modules:
        __import__(module.name)
