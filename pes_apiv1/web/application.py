import logging
from importlib import metadata

import sentry_sdk
from fastapi import FastAPI
from fastapi.responses import UJSONResponse
from sentry_sdk.integrations.fastapi import FastApiIntegration
from sentry_sdk.integrations.logging import LoggingIntegration
from sentry_sdk.integrations.sqlalchemy import SqlalchemyIntegration

from pes_apiv1.log import configure_logging
from pes_apiv1.settings import settings
from pes_apiv1.web.api.router import api_router
from pes_apiv1.web.lifespan import lifespan_setup


def get_app() -> FastAPI:
    """
    Get FastAPI application.

    This is the main constructor of an application.

    :return: application.
    """
    configure_logging()
    if settings.PES_APIV1_SENTRY_DSN:
        # Enables sentry integration.
        sentry_sdk.init(
            dsn=settings.PES_APIV1_SENTRY_DSN,
            traces_sample_rate=settings.PES_APIV1_SENTRY_SAMPLE_RATE,
            environment=settings.PES_APIV1_ENVIRONMENT,
            integrations=[
                FastApiIntegration(transaction_style="endpoint"),
                LoggingIntegration(
                    level=logging.getLevelName(
                        settings.PES_APIV1_LOG_LEVEL.value,
                    ),
                    event_level=logging.ERROR,
                ),
                SqlalchemyIntegration(),
            ],
        )
    app = FastAPI(
        title="pes_apiv1",
        version=metadata.version("pes_apiv1"),
        lifespan=lifespan_setup,
        docs_url="/api/docs",
        redoc_url="/api/redoc",
        openapi_url="/api/openapi.json",
        default_response_class=UJSONResponse,
    )

    # Main router for the API.
    app.include_router(router=api_router, prefix="/api")

    return app
