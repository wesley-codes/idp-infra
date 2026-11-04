variable "github_token" {
    description = "Read-only GitHub token ArgocCD uses to read idp-infra repo"
    type = string
    sensitive = true
}