from fastapi.routing import APIRouter

from pes_apiv1.web.api import monitoring
from pes_apiv1.web.api.loan.views import router as loan_router

api_router = APIRouter()
api_router.include_router(monitoring.router)
api_router.include_router(loan_router)
