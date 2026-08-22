output "repository_url" {
  value = aws_ecr_repository.this.repository_url
}

output "github_actions_role_arn" {
  value = aws_ecr_repository.this.arn
}