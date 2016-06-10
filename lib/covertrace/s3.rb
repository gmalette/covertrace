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
end

Covertrace.after_suite do |dependencies|
  Covertrace::S3.put_object(dependencies.to_json)
end
