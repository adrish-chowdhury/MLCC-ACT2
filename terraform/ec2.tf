# Optional single-instance host for the web app (testing only).
data "aws_ssm_parameter" "al2023" {
  provider = aws.app
  name     = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_iam_role" "app" {
  count    = var.deploy_app ? 1 : 0
  provider = aws.app
  name     = "${var.bucket_prefix}-app"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Lets you open a shell via SSM Session Manager - no SSH key or port 22 needed.
resource "aws_iam_role_policy_attachment" "ssm" {
  count      = var.deploy_app ? 1 : 0
  provider   = aws.app
  role       = aws_iam_role.app[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "app" {
  count    = var.deploy_app ? 1 : 0
  provider = aws.app
  name     = "${var.bucket_prefix}-app"
  role     = aws_iam_role.app[0].name
}

resource "aws_security_group" "app" {
  count    = var.deploy_app ? 1 : 0
  provider = aws.app
  name     = "${var.bucket_prefix}-app"

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "app" {
  count                  = var.deploy_app ? 1 : 0
  provider               = aws.app
  ami                    = data.aws_ssm_parameter.al2023.value
  instance_type          = "t3.small"
  iam_instance_profile   = aws_iam_instance_profile.app[0].name
  vpc_security_group_ids = [aws_security_group.app[0].id]

  user_data = <<-EOT
    #!/bin/bash
    set -ex
    dnf install -y git tar xz
    curl -fsSL https://nodejs.org/dist/v22.12.0/node-v22.12.0-linux-x64.tar.xz | tar -xJ -C /usr/local --strip-components=1
    git clone ${var.repo_url} /opt/app
    cd /opt/app
    echo 'GEMINI_API_KEY="${var.gemini_api_key}"' > .env
    npm install
    npm run build
    cat > /etc/systemd/system/app.service <<'UNIT'
    [Unit]
    Description=Digit AIpro
    After=network.target
    [Service]
    WorkingDirectory=/opt/app
    Environment=NODE_ENV=production
    Environment=PORT=3000
    ExecStart=/usr/local/bin/npx tsx server.ts
    Restart=always
    [Install]
    WantedBy=multi-user.target
    UNIT
    systemctl daemon-reload
    systemctl enable --now app
  EOT

  tags = {
    Name = "${var.bucket_prefix}-app"
  }
}
