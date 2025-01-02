data "aws_ssm_parameter" "ecs_optimized" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/kernel-5.10/recommended/image_id"
}
