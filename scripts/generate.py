#!/usr/bin/env python3
"""
Render Jinja2 templates from demo-config.yaml into deployable lab files.

Usage: python3 scripts/generate.py [--config demo-config.yaml]
"""

import argparse
import os
import sys

try:
    import yaml
except ImportError:
    sys.exit("Missing dependency: pyyaml\n  pip install pyyaml")

try:
    from jinja2 import Environment, FileSystemLoader, StrictUndefined
except ImportError:
    sys.exit("Missing dependency: jinja2\n  pip install jinja2")


ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

TEMPLATES = [
    ("topology.clab.yml.j2", "clab/topology.clab.yml"),
    ("mgmt-sw01.cfg.j2", "clab/configs/mgmt-sw01.cfg"),
    ("bootstrap.py.j2", "clab/bootstrap/bootstrap.py"),
    ("bootstrap-cv.py.j2", "clab/bootstrap/bootstrap-cv.py"),
]


def validate_config(config):
    errors = []

    if config.get("bootstrap_type") not in ("local", "cloudvision"):
        errors.append(
            'bootstrap_type must be "local" or "cloudvision", '
            'got: %s' % config.get("bootstrap_type")
        )

    if config.get("bootstrap_type") == "local":
        version = config.get("desired_eos_version", "")
        image_dir = os.path.join(ROOT_DIR, "clab", "eos_images")
        expected = "EOS-%s.swi" % version
        if os.path.isdir(image_dir):
            available = os.listdir(image_dir)
            if expected not in available:
                errors.append(
                    "desired_eos_version '%s' does not match any image in clab/eos_images/.\n"
                    "  Expected: %s\n"
                    "  Available: %s" % (version, expected, ", ".join(sorted(available)))
                )

    if config.get("bootstrap_type") == "cloudvision":
        if not config.get("enrollment_token") or config["enrollment_token"] == "token-here":
            errors.append("enrollment_token must be set for cloudvision bootstrap")

    if config.get("enable_bridge"):
        iface = config.get("bridge_interface", "")
        if not iface:
            errors.append("bridge_interface is required when enable_bridge is true")
        if not config.get("egress_ip"):
            errors.append("egress_ip is required when enable_bridge is true")
        if not config.get("egress_gateway"):
            errors.append("egress_gateway is required when enable_bridge is true")

    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--config",
        default=os.path.join(ROOT_DIR, "demo-config.yaml"),
        help="Path to config file (default: demo-config.yaml)",
    )
    args = parser.parse_args()

    with open(args.config) as f:
        config = yaml.safe_load(f)

    errors = validate_config(config)
    if errors:
        print("Configuration errors:")
        for e in errors:
            print("  - %s" % e)
        sys.exit(1)

    env = Environment(
        loader=FileSystemLoader(os.path.join(ROOT_DIR, "templates")),
        undefined=StrictUndefined,
        keep_trailing_newline=True,
    )

    for template_name, output_path in TEMPLATES:
        template = env.get_template(template_name)
        rendered = template.render(**config)
        full_path = os.path.join(ROOT_DIR, output_path)
        os.makedirs(os.path.dirname(full_path), exist_ok=True)
        with open(full_path, "w") as f:
            f.write(rendered)
        print("  Generated: %s" % output_path)

    print("\nDone. Run 'make start' to deploy the lab.")


if __name__ == "__main__":
    main()
