resource "aws_s3_bucket" "polly_audio_bucket" {
  bucket = "my-tts-audio-bucket-123456"

  tags = {
    Name        = "TextToSpeechBucket"
    Environment = "Dev"
  }
}

resource "aws_s3_bucket_public_access_block" "polly_audio_bucket_access" {
  bucket = aws_s3_bucket.polly_audio_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

