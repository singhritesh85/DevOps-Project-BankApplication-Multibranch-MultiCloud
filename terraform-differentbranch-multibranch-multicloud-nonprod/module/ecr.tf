resource "aws_ecr_repository" "ecr" {
  name                 = "bankapp"
  image_tag_mutability = "MUTABLE"   ### "IMMUTABLE"
  force_delete = true

  image_scanning_configuration {
    scan_on_push = false   ### true
  }

  encryption_configuration {
    encryption_type = "AES256"   ### "KMS"
#    kms_key = ""
  }
}
