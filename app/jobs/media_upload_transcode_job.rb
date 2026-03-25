require "open3"
require "tmpdir"

class MediaUploadTranscodeJob < ApplicationJob
  queue_as :default

  # Конвертируем webm → mp4 и кладём mp4 рядом в S3/MinIO.
  def perform(media_upload_id)
    media_upload = MediaUpload.find_by(id: media_upload_id)
    return if media_upload.nil?

    meta = media_upload.upload_meta || {}
    source_key = meta["key"].to_s
    return if source_key.blank?

    service = S3MultipartUploadService.new

    Dir.mktmpdir("media_upload_transcode") do |dir|
      source_path = File.join(dir, "source.webm")
      out_path = File.join(dir, "out.mp4")

      service.download_to_file(key: source_key, path: source_path)

      ffmpeg_cmd = [
        "ffmpeg",
        "-y",
        "-i", source_path,
        "-c:v", "libx264",
        "-pix_fmt", "yuv420p",
        "-movflags", "+faststart",
        out_path
      ]

      _stdout, stderr, status = Open3.capture3(*ffmpeg_cmd)
      unless status.success?
        media_upload.update!(status: "failed", error_message: "ffmpeg failed: #{stderr.to_s.strip.presence || status.exitstatus}")
        return
      end

      mp4_key = build_mp4_key(source_key)
      service.upload_file(key: mp4_key, path: out_path, content_type: "video/mp4")

      next_meta = meta.merge(
        "source_key" => source_key,
        "source_url" => service.object_public_url(source_key),
        "mp4_key" => mp4_key
      )

      media_upload.update!(
        status: "ready",
        url: service.object_public_url(mp4_key),
        upload_meta: next_meta,
        error_message: nil
      )
    end
  rescue S3MultipartUploadService::ConfigError => e
    MediaUpload.where(id: media_upload_id).update_all(status: "failed", error_message: e.message)
  rescue StandardError => e
    MediaUpload.where(id: media_upload_id).update_all(status: "failed", error_message: e.message)
  end

  private

  def build_mp4_key(source_key)
    base = source_key.sub(/\.(webm|mp4)\z/i, "")
    "#{base}.mp4"
  end
end

