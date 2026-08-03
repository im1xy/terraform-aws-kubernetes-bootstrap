import os
import yaml
import boto3
import base64
import logging

from botocore.signers import RequestSigner
from pathlib import Path

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def config(tmp: Path, cluster: str) -> None:
    workdir = tmp / ".kube"
    workdir.mkdir(parents=True, exist_ok=True)
    kubeconfig_path = workdir / "config"

    session = boto3.session.Session()
    region = session.region_name
    eks = session.client("eks", region_name=region)
    response = eks.describe_cluster(name=cluster)["cluster"]
    sts = session.client("sts", region_name=region)
    signer = RequestSigner(
        region_name=region,
        service_id=sts.meta.service_model.service_id,
        signing_name=sts.meta.service_model.endpoint_prefix,
        signature_version=sts.meta.service_model.signature_version,
        credentials=session.get_credentials(),
        event_emitter=sts.meta.events,
    )
    parameters = {
        "method": "GET",
        "url": f"https://sts.{region}.amazonaws.com/?Action=GetCallerIdentity&Version=2011-06-15",
        "body": {},
        "headers": {"x-k8s-aws-id": cluster},
        "context": {},
    }
    signed_url = signer.generate_presigned_url(parameters, region_name=region, operation_name="GetCallerIdentity", expires_in=300)
    token = "k8s-aws-v1." + base64.urlsafe_b64encode(signed_url.encode("utf-8")).decode("utf-8").rstrip("=")

    kubeconfig_content = {
        "apiVersion": "v1",
        "kind": "Config",
        "clusters": [{
            "name": cluster,
            "cluster": {
                "server": response["endpoint"],
                "certificate-authority-data": response["certificateAuthority"]["data"],
            },
        }],
        "contexts": [{
            "name": cluster,
            "context": {
                "cluster": cluster,
                "user": cluster,
            },
        }],
        "current-context": cluster,
        "users": [{
            "name": cluster,
            "user": {
                "token": token,
            },
        }],
    }

    kubeconfig_path.write_text(yaml.safe_dump(kubeconfig_content, sort_keys=False), encoding="utf-8")
    os.environ["KUBECONFIG"] = str(kubeconfig_path)
    logger.info(f"KUBECONFIG: {kubeconfig_path}")
