packer {
  required_plugins {
    amazon = {
      version = ">= 1.3.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "region" {
  type    = string
  default = "ap-south-1"
}

variable "instance_type" {
  type    = string
  default = "t3.medium"
}

locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}

source "amazon-ebs" "grafana" {
  region        = var.region
  instance_type = var.instance_type
  ssh_username  = "ubuntu"

  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    owners      = ["099720109477"]
    most_recent = true
  }

  ami_name = "grafana-base-${local.timestamp}"
  tags = {
    Name    = "grafana-base"
    Builder = "packer"
  }
}

build {
  name    = "grafana-aws-platform"
  sources = ["source.amazon-ebs.grafana"]

  provisioner "shell" {
    script          = "scripts/install-grafana.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  provisioner "file" {
    source      = "../ansible"
    destination = "/tmp/ansible"
  }

  provisioner "file" {
    source      = "../grafana"
    destination = "/tmp/grafana"
  }

  provisioner "shell" {
    inline = [
      "sudo mkdir -p /opt/grafana-platform",
      "sudo mv /tmp/ansible /opt/grafana-platform/ansible",
      "sudo mv /tmp/grafana /opt/grafana-platform/grafana",
      "sudo chown -R root:root /opt/grafana-platform/ansible /opt/grafana-platform/grafana",
    ]
  }
}
