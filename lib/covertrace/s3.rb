gem "aws-sdk", "~> 2.3"
require "net/http"

module Covertrace::S3
  extend self

  RemoteFileNotFound = Class.new(StandardError)

  attr_accessor(
    :bucket,
    :file_path,
    :region,
  )

  def put_object(json)
    client = Aws::S3::Client.new(region: region)
    client.put_object(
      bucket: bucket,
      key: "#{file_path}.json",
      body: json,
    )
  end

  def http_download
    content = cache("/tmp/coverage-#{file_path}.json") do
      url = "http://#{bucket}.s3-website-#{region}.amazonaws.com/#{bucket}/#{file_path}.json"
      resp = Net::HTTP.get_response(URI(url))

      raise(RemoteFileNotFound, url) unless resp.is_a?(Net::HTTPSuccess)

      resp.body
    end

    JSON.parse(content)
  end

  private

  def cache(filename, &block)
    file = Pathname.new(filename)

    if !file.exist?
      file.write(block.call)
    end

    file.read
  end
end

Covertrace.after_suite do |dependencies|
  Covertrace::S3.put_object(dependencies.to_json)
end
