# Static website (built React app) in its own bucket, separate from the mirrored A/B pair.
locals {
  site_bucket = "${var.bucket_prefix}-site-${data.aws_caller_identity.me.account_id}"
  site_files  = fileset(var.site_dist_dir, "**")
  mime = {
    html  = "text/html"
    js    = "application/javascript"
    css   = "text/css"
    json  = "application/json"
    svg   = "image/svg+xml"
    png   = "image/png"
    jpg   = "image/jpeg"
    ico   = "image/x-icon"
    ipynb = "application/json"
  }
}

resource "aws_s3_bucket" "site" {
  provider      = aws.site
  bucket        = local.site_bucket
  force_destroy = true
}

resource "aws_s3_bucket_website_configuration" "site" {
  provider = aws.site
  bucket   = aws_s3_bucket.site.id
  index_document { suffix = "index.html" }
  error_document { key = "index.html" }
}

resource "aws_s3_bucket_public_access_block" "site" {
  provider                = aws.site
  bucket                  = aws_s3_bucket.site.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "site" {
  provider   = aws.site
  bucket     = aws_s3_bucket.site.id
  depends_on = [aws_s3_bucket_public_access_block.site]
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = "*"
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.site.arn}/*"
    }]
  })
}

resource "aws_s3_object" "site" {
  provider     = aws.site
  for_each     = local.site_files
  bucket       = aws_s3_bucket.site.id
  key          = each.value
  source       = "${var.site_dist_dir}/${each.value}"
  etag         = filemd5("${var.site_dist_dir}/${each.value}")
  content_type = lookup(local.mime, reverse(split(".", each.value))[0], "application/octet-stream")
}
