module "kms" {
  source  = "terraform-aws-modules/kms/aws"
  version = "2.1.0"

  deletion_window_in_days = 7
  description             = "ec2 key for testing"
  enable_key_rotation     = false
  is_enabled              = true
  key_usage               = "ENCRYPT_DECRYPT"
  multi_region            = false

  aliases = ["ec2/testing"]

}

module "ec2-instance" {
  source                      = "terraform-aws-modules/ec2-instance/aws"
  version                     = "5.6.0"
  name                        = "bastion"
  ami                         = "ami-023c11a32b0207432"
  instance_type               = "t3.medium"
  subnet_id                   = "subnet-0241994880cd395eb"
  vpc_security_group_ids      = ["sg-0ea884b195d4fd56b"]
  associate_public_ip_address = true
  availability_zone           = ""
  iam_instance_profile        = aws_iam_instance_profile.instance_profile.name
  user_data                   = templatefile("${path.module}/userdatafile/scripts_bastion/cloud_init.yaml", { user0 = local.users[0], secret_name0 = aws_secretsmanager_secret.userlinux-pass.name })
  user_data_replace_on_change = true
  hibernation                 = true
  enable_volume_tags          = true
  root_block_device = [
    {
      encrypted   = true
      kms_key_id  = module.kms.key_id
      volume_type = "gp3"
      throughput  = 200
      volume_size = 20
    },
  ]
  ebs_block_device = [
    {
      device_name = "/dev/sdf"
      volume_type = "gp3"
      volume_size = 20
      throughput  = 200
      encrypted   = true
      encrypted   = true
      kms_key_id  = module.kms.key_id
    }
  ]
}


resource "aws_iam_policy" "custom_policy" {
  name = "segoja7-policy-testing"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : [
          "secretsmanager:GetSecretValue",
        ],
        "Resource" : [aws_secretsmanager_secret_version.userlinux-pass-val.arn],
        "Effect" : "Allow"
        "Condition" : {
          "DateGreaterThan" : { "aws:CurrentTime" :timestamp() },
          "DateLessThan" : { "aws:CurrentTime" : timeadd(timestamp(), "5m") }
        }
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:GenerateDataKey"
        ],
        "Resource" : module.kms.key_arn
      }
    ]
  })
}

resource "aws_iam_role" "custom_role" {
  name = "custom-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        "Sid" : "EC2AssumeRole",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "ec2.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "policy-attachment" {
  for_each = {
    "AmazonSSMManagedInstanceCore" = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "CustomPolicy" = aws_iam_policy.custom_policy.arn,
  }
  policy_arn = each.value
  role       = aws_iam_role.custom_role.name
}

resource "aws_iam_instance_profile" "instance_profile" {
  name = "custom-profile"
  role = aws_iam_role.custom_role.name
}

resource "aws_secretsmanager_secret" "userlinux-pass" {
  name                    = "secrets/bastion/${local.users[0]}"
  description             = "password secret for user: ${local.users[0]}"
  recovery_window_in_days = 0
  kms_key_id              = module.kms.key_id
}

resource "aws_secretsmanager_secret_version" "userlinux-pass-val" {
  secret_id = aws_secretsmanager_secret.userlinux-pass.id
  secret_string = jsonencode({
    username = local.users[0]
    password = random_password.user_password.result
  })
}

resource "random_password" "user_password" {
  length  = 16
  special = true
}


