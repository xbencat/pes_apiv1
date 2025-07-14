import uvicorn

from pes_apiv1.gunicorn_runner import GunicornApplication
from pes_apiv1.settings import settings


def main() -> None:
    """Entrypoint of the application."""
    if settings.PES_APIV1_RELOAD:
        uvicorn.run(
            "pes_apiv1.web.application:get_app",
            workers=settings.PES_APIV1_WORKERS_COUNT,
            host=settings.PES_APIV1_HOST,
            port=settings.PES_APIV1_PORT,
            reload=settings.PES_APIV1_RELOAD,
            log_level=settings.PES_APIV1_LOG_LEVEL.value.lower(),
            factory=True,
        )
    else:
        # We choose gunicorn only if reload
        # option is not used, because reload
        # feature doesn't work with gunicorn workers.
        GunicornApplication(
            "pes_apiv1.web.application:get_app",
            host=settings.PES_APIV1_HOST,
            port=settings.PES_APIV1_PORT,
            workers=settings.PES_APIV1_WORKERS_COUNT,
            factory=True,
            accesslog="-",
            loglevel=settings.PES_APIV1_LOG_LEVEL.value.lower(),
            access_log_format='%(h)s %(l)s %(u)s %(t)s "%(r)s" %(s)s %(b)s "%(f)s" "%(a)s"',
        ).run()


if __name__ == "__main__":
    main()
