resource "aws_ecr_repository" "this" {
  for_each = toset(var.repositories)

  name                 = each.value
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(var.tags, {
    Name = each.value
  })
}

resource "aws_ecr_lifecycle_policy" "keep_last" {
  for_each = var.lifecycle_keep_last > 0 ? toset(var.repositories) : toset([])

  repository = aws_ecr_repository.this[each.value].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last ${var.lifecycle_keep_last} images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.lifecycle_keep_last
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
