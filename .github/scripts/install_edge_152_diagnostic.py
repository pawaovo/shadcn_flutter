#!/usr/bin/env python3
"""Install the exact diagnostic distribution on a disposable Linux CI runner."""

import argparse
import hashlib
import json
import platform
import subprocess
import urllib.request
import zipfile
from pathlib import Path


VERSION = "152.0.4191.53"
BASE_COMMIT = "0f8db35bd756803f769797886b295f32bac6b211"
BROWSER = {
    "url": "https://packages.microsoft.com/repos/edge/pool/main/m/microsoft-edge-stable/microsoft-edge-stable_152.0.4191.53-1_amd64.deb",
    "sha256": "b3322445fbe6ce1e0bcff84ebbe0edea365e0eaf498b1ef6136dda52dea6e3a7",
    "checksum_source": "https://packages.microsoft.com/repos/edge/dists/stable/main/binary-amd64/Packages.gz",
    "filename": "microsoft-edge-stable.deb",
}
DRIVER = {
    "url": "https://msedgedriver.microsoft.com/152.0.4191.53/edgedriver_linux64.zip",
    "sha256": "58deca365a57cdf9fb2853da0fa3953d1bb1d90963943eab2172dea4cf5cb61f",
    "checksum_source": "SHA-256 of the complete official HTTPS distribution, verified before the diagnostic run",
    "filename": "edgedriver_linux64.zip",
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--install-dir", type=Path, required=True)
    parser.add_argument("--evidence-dir", type=Path, required=True)
    parser.add_argument("--sample", type=int, choices=(1, 2, 3), required=True)
    args = parser.parse_args()
    if platform.system() != "Linux" or platform.machine() != "x86_64":
        parser.error("This installer is only for the disposable Ubuntu amd64 CI runner")
    args.install_dir.mkdir(parents=True, exist_ok=True)
    args.evidence_dir.mkdir(parents=True, exist_ok=True)
    report = {
        "sample": args.sample,
        "expected_version": VERSION,
        "base_commit": BASE_COMMIT,
        "diagnostic_commit": subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip(),
        "platform": platform.platform(),
        "downloads": {},
        "status": "preparing_exact_distribution",
    }

    def save():
        (args.evidence_dir / "distribution.json").write_text(json.dumps(report, indent=2) + "\n")

    save()
    try:
        for name, distribution in (("browser", BROWSER), ("driver", DRIVER)):
            record = dict(distribution)
            report["downloads"][name] = record
            save()
            destination = args.install_dir / distribution["filename"]
            with urllib.request.urlopen(distribution["url"], timeout=120) as response:
                record["http_status"] = response.status
                record["final_url"] = response.url
                record["headers"] = dict(response.headers)
                digest = hashlib.sha256()
                size = 0
                with destination.open("wb") as output:
                    while chunk := response.read(1024 * 1024):
                        output.write(chunk)
                        digest.update(chunk)
                        size += len(chunk)
                record["downloaded_sha256"] = digest.hexdigest()
                record["downloaded_bytes"] = size
            save()
            if record["downloaded_sha256"] != distribution["sha256"]:
                raise ValueError(f"Exact official {name} distribution checksum mismatch")

        deb = args.install_dir / BROWSER["filename"]
        fields = subprocess.check_output(
            ["dpkg-deb", "--show", "--showformat=${Package}\t${Version}\t${Architecture}", str(deb)],
            text=True,
        )
        report["package_identity"] = fields
        if fields != f"microsoft-edge-stable\t{VERSION}-1\tamd64":
            raise ValueError(f"Unexpected browser package identity: {fields}")
        with (args.evidence_dir / "package-install.log").open("w") as log:
            subprocess.run(["sudo", "apt-get", "install", "--yes", "--allow-downgrades", str(deb)],
                           stdout=log, stderr=subprocess.STDOUT, check=True)
        driver = args.install_dir / "msedgedriver"
        with zipfile.ZipFile(args.install_dir / DRIVER["filename"]) as archive:
            driver.write_bytes(archive.read("msedgedriver"))
        driver.chmod(0o755)
        installed_browser = subprocess.check_output(["microsoft-edge", "--version"], text=True).strip()
        installed_driver = subprocess.check_output([str(driver), "--version"], text=True).strip()
        report["installed_browser"] = installed_browser
        report["installed_driver"] = installed_driver
        report["installed_driver_sha256"] = hashlib.sha256(driver.read_bytes()).hexdigest()
        if installed_browser != f"Microsoft Edge {VERSION}":
            raise ValueError(f"Expected exact Edge {VERSION}; got {installed_browser}")
        if not installed_driver.startswith(f"Microsoft Edge WebDriver {VERSION} "):
            raise ValueError(f"Expected exact Edge driver {VERSION}; got {installed_driver}")
        report["status"] = "exact_distribution_verified"
        print(installed_browser)
        print(installed_driver)
    except Exception as error:
        report["status"] = "exact_distribution_unavailable_or_invalid"
        report["error"] = str(error)
        raise
    finally:
        save()


if __name__ == "__main__":
    main()
