data "aws_ami" "ecs_optimized" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-*-x86_64-ebs"]
  }

  filter {
    name   = "owner-id"
    values = ["137112412989"] # Amazon ECS AMI owner ID
  }
}
