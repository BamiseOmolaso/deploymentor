terraform {
  backend "s3" {
    bucket       = "deploymentor-terraform-state"
    key          = "deploymentor/prod/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}

