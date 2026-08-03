import os
import logging
import tempfile
import kube
import helm

from pathlib import Path

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def handler(event, context):
    logger.info(f"Received event: {event}")
    logger.info(f"Received context: {context}")

    try:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)

            cluster = os.environ["CLUSTER"]
            kube.config(tmp, cluster)

            charts = event["charts"]
            for name, chart in charts.items():
                logger.info(f"Installing {name} chart")
                helm.install(tmp, helm.Chart(
                    release=name,
                    chart=chart["chart"],
                    repository=chart["repository"],
                    version=chart["version"],
                    namespace=chart["namespace"],
                    values=chart.get("values", {}),
                    wait=chart["wait"],
                    timeout=chart["timeout"],
                    create_namespace=chart["create_namespace"],
                ))
                logger.info(f"Chart {name} installed successfully")

    except Exception as e:
        logger.error(f"Provisioning failed: {e}")
        raise

    return {"status": "Provisioning successful"}
